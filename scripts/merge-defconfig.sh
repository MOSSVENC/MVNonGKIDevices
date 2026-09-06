#!/usr/bin/env bash
#
# merge-defconfig.sh — assemble the final polaris .config from:
#
#   1. baseline:        vendor/xiaomi/mi845_defconfig   (LOS-official base)
#   2. device fragment: vendor/xiaomi/polaris.config    (LOS device tree +=)
#   3. feature fragments (only the enabled ones; caller supplies paths):
#        resukisu.config.fragment   (CONFIG_KSU / MANUAL_HOOK ...)
#        bbg.config.fragment        (CONFIG_BBG ...)
#        droidspace.config          (patches/droidspace/common/droidspace.config)
#
# Usage:
#   merge-defconfig.sh <kernel-root> <out-dir> <fragment1> [<fragment2> ...]
#
# Method (Kbuild-native; no dependence on scripts/kconfig/merge_config.sh):
#   1. concatenate baseline mi845_defconfig + polaris.config + fragments into
#      one de-duplicated "allconfig" file (later same-name entries override
#      earlier ones, incl. "# CONFIG_X is not set" vs "CONFIG_X=y")
#   2. make KCONFIG_ALLCONFIG=<file> alldefconfig
#      -> produces a fully resolved .config from the allconfig alone
#      (this also fills dependency-driven symbols with their defaults)
#   3. make olddefconfig (belt & braces)
#   4. assert critical symbols; any miss fails the build loudly
#
# The kernel tree must already be patched and integrated (resukisu / bbg
# setup.sh run) BEFORE this runs, so their Kconfig symbols resolve.
#
set -euo pipefail

KROOT="${1:?usage: merge-defconfig.sh <kernel-root> <out-dir> [fragments...]}"
OUT="${2:?}"
shift 2

cd "$KROOT"

[ -f Makefile ] || { echo "ERROR: $KROOT is not a kernel root (no Makefile)" >&2; exit 1; }
V=$(awk '/^VERSION *=/{v=$3} /^PATCHLEVEL *=/{p=$3} END{print v"."p}' Makefile)
echo "Kernel version: $V"

# Baseline defconfig + device fragments are device-specific; override via
# env (BASE_DEFCONFIG / DEVICE_FRAGMENTS="frag1 frag2"). Defaults keep the
# original polaris behaviour.
BASE="${BASE_DEFCONFIG:-arch/arm64/configs/vendor/xiaomi/mi845_defconfig}"
[ -f "$BASE" ] || { echo "ERROR: baseline defconfig not found: $BASE" >&2; exit 1; }

mkdir -p "$OUT"
RAW="$OUT/.allconfig.raw"
rm -f "$RAW"

append_cfg() { # file
  local f="$1"
  [ -f "$f" ] || { echo "WARN: config source not found, skipped: $f"; return; }
  echo "# ==== $f" >> "$RAW"
  # extract config lines (value forms: CONFIG_X=y / CONFIG_X="str" / "# CONFIG_X is not set")
  grep -E "^(# )?CONFIG_[A-Za-z0-9_]+[ =]" "$f" >> "$RAW" || true
}

echo "==> 1/5 collecting config sources"
append_cfg "$BASE"                       # baseline (device family base)
for frag in ${DEVICE_FRAGMENTS:-arch/arm64/configs/vendor/xiaomi/polaris.config}; do
  append_cfg "$frag"                     # device fragment(s)
done
for f in "$@"; do append_cfg "$f"; done  # feature fragments (later wins)

# --- build-hardening override (always): this 4.9 tree predates GCC 10+ and
# trips -Werror=format etc. on modern cross compilers. CC_WERROR must stay
# off for a clean build regardless of feature selection.
echo "# CONFIG_CC_WERROR is not set" >> "$RAW"
echo "# CONFIG_CC_WERROR_STRICT is not set" >> "$RAW"   # harmless if absent

# --- LOCALVERSION override (opt-in): CLEAR_LOCALVERSION=true forces an
# empty CONFIG_LOCALVERSION (e.g. beryllium ships "-Helios™" in its stock
# defconfig and we want a plain <kernel>[-g<sha>] version string).
if [ "${CLEAR_LOCALVERSION:-false}" = "true" ]; then
  echo 'CONFIG_LOCALVERSION=""' >> "$RAW"
fi

# --- KALLSYMS_ALL override (always): ReSukiSU resolves its selinux static
# symbols (write_op / sel_handle_status_ops / selinux_status_page|lock /
# sel_mutex / policy_rwlock / ...) through the kallsyms table when
# CONFIG_KALLSYMS_ALL=y and falls back to `extern` direct references when
# it is off. The extern path requires those symbols to be manually
# de-static'ed in the kernel source (official static_export_check.mk);
# this repo relies on the KALLSYMS_ALL path, so no de-static patches are
# shipped. ReSukiSU's own Kconfig only `select KALLSYMS`; it cannot select
# KALLSYMS_ALL because that symbol `depends on DEBUG_KERNEL && KALLSYMS`
# and select cannot cross a depends-on. So pin the whole chain here
# instead of relying on the LOS baseline to keep it enabled.
echo "CONFIG_DEBUG_KERNEL=y"      >> "$RAW"   # KALLSYMS_ALL dependency
echo "CONFIG_KALLSYMS=y"          >> "$RAW"   # ReSukiSU select + dep
echo "CONFIG_KALLSYMS_ALL=y"      >> "$RAW"   # static symbols into table

# --- de-dup: keep the LAST occurrence of each symbol ---
ALLCONFIG="$OUT/.allconfig"
dedupe() {
  tac "$1" | awk '{
    line=$0
    if (match($0, /^# CONFIG_[A-Za-z0-9_]+/)) key=substr($0,3,RLENGTH-2)
    else if (match($0, /^CONFIG_[A-Za-z0-9_]+/)) key=substr($0,1,RLENGTH)
    else { print; next }
    if (!seen[key]++) print line
  }' | tac
}
dedupe "$RAW" > "$ALLCONFIG"
rm -f "$RAW"
echo "    allconfig: $(wc -l < "$ALLCONFIG") config lines -> $ALLCONFIG"

echo "==> 2/5 make KCONFIG_ALLCONFIG alldefconfig (O=$OUT)"
make O="$OUT" ARCH=arm64 KCONFIG_ALLCONFIG="$ALLCONFIG" alldefconfig >/dev/null

echo "==> 3/5 olddefconfig"
make O="$OUT" ARCH=arm64 olddefconfig >/dev/null

echo "==> 4/5 asserting critical config symbols"
CFG="$OUT/.config"
assert_cfg() { # symbol
  local sym="$1"
  if grep -qE "^${sym}=y$" "$CFG"; then
    echo "   OK   $sym=y"
  else
    echo "   FAIL $sym (wanted =y)" >&2
    return 1
  fi
}

rc=0

# KALLSYMS_ALL must survive into the final .config: ReSukiSU resolves
# every selinux static symbol through kallsyms only when this is y.
# Fail loudly if it got dropped.
assert_cfg CONFIG_KALLSYMS || rc=1
assert_cfg CONFIG_KALLSYMS_ALL || rc=1

if [ "${ENABLE_RESUKISU:-true}" = "true" ]; then
  assert_cfg CONFIG_KSU || rc=1
  assert_cfg CONFIG_KSU_MANUAL_HOOK || rc=1
  # hook_extra: lsm (default) -> three AUTO_* options must be ON;
  #             manual -> the alt source patches are used, AUTO_* must be OFF.
  if [ "${HOOK_EXTRA:-lsm}" = "manual" ]; then
    for s in CONFIG_KSU_MANUAL_HOOK_AUTO_SETUID_HOOK \
             CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK \
             CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK; do
      if grep -qE "^# ${s} is not set$" "$CFG"; then
        echo "   OK   $s is not set"
      else
        echo "   FAIL $s (manual hook mode wants it off)" >&2
        rc=1
      fi
    done
  else
    for s in CONFIG_KSU_MANUAL_HOOK_AUTO_SETUID_HOOK \
             CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK \
             CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK; do
      assert_cfg "$s" || rc=1
    done
  fi
fi
if [ "${ENABLE_BBG:-true}" = "true" ]; then
  assert_cfg CONFIG_BBG || rc=1
fi
if [ "${ENABLE_DROIDSPACE:-true}" = "true" ]; then
  for s in CONFIG_SYSVIPC CONFIG_POSIX_MQUEUE CONFIG_PID_NS CONFIG_UTS_NS \
           CONFIG_IPC_NS CONFIG_NET_NS CONFIG_USER_NS CONFIG_DEVTMPFS \
           CONFIG_VETH CONFIG_CGROUP_DEVICE CONFIG_CGROUP_PIDS; do
    assert_cfg "$s" || rc=1
  done
  if grep -qE "^# CONFIG_ANDROID_PARANOID_NETWORK is not set$" "$CFG"; then
    echo "   OK   CONFIG_ANDROID_PARANOID_NETWORK is not set"
  else
    echo "   FAIL CONFIG_ANDROID_PARANOID_NETWORK (should be off)" >&2
    rc=1
  fi
fi

if [ "${ENABLE_DATA_ISOLATION:-true}" = "true" ]; then
  # The isolation semantics are enforced by the sdcardfs source patch
  # (patches/sdcardfs), so only the filesystem itself must be present.
  assert_cfg CONFIG_SDCARD_FS || rc=1
fi

[ "$rc" = 0 ] || { echo "merge-defconfig.sh: assertions failed" >&2; exit 1; }
echo "==> 5/5 done: $CFG"
