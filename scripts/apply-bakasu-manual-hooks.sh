#!/usr/bin/env bash
#
# apply-bakasu-manual-hooks.sh — apply the mandatory BakaSU source hooks and,
# only for hook_extra=manual, the optional input/setuid/sys_read hooks.
#
# usage: apply-bakasu-manual-hooks.sh <kernel-root> <mandatory-spec> [<extra-spec>]
#
#   <mandatory-spec>  directory or space-separated patch list containing the
#                     mandatory stat/exec/open/reboot patches for the target
#                     tree. Optional 0010-0012 patches in a directory are
#                     selected only through <extra-spec>.
#   <extra-spec>      manual mode only:
#                       glob:<pattern>  sorted matches of the pattern
#                       <directory>     optional 0010-0012 patches in it
#                       <list>          explicit optional patch files
#
# The helper keeps the two hook groups disjoint. A directory shorthand must
# not silently apply 0010-0012 when the caller requested the LSM AUTO path.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kroot="${1:?usage: apply-bakasu-manual-hooks.sh <kernel-root> <mandatory-spec> [<extra-spec>]}"
mandatory_spec="${2:?usage: apply-bakasu-manual-hooks.sh <kernel-root> <mandatory-spec> [<extra-spec>]}"
extra_spec="${3:-}"

is_optional_patch() {
  case "$(basename "$1")" in
    001[0-2]-*.patch) return 0 ;;
  esac
  return 1
}

mandatory_patches=()
optional_patches=()

append_mandatory_spec() {
  local spec="$1" arg patch
  local -a words=()
  read -r -a words <<< "$spec"
  [ "${#words[@]}" -gt 0 ] || {
    echo "ERROR: empty mandatory patch specification" >&2
    exit 2
  }
  for arg in "${words[@]}"; do
    if [ -d "$arg" ]; then
      local -a files=()
      mapfile -t files < <(find "$arg" -maxdepth 1 -type f -name '*.patch' -print | sort)
      [ "${#files[@]}" -gt 0 ] || {
        echo "ERROR: no *.patch files in $arg" >&2
        exit 1
      }
      for patch in "${files[@]}"; do
        case "$(basename "$patch")" in
          0000-*|001[0-2]-*) continue ;;
        esac
        mandatory_patches+=("$patch")
      done
    elif [ -f "$arg" ]; then
      if is_optional_patch "$arg"; then
        optional_patches+=("$arg")
      else
        mandatory_patches+=("$arg")
      fi
    else
      echo "ERROR: missing mandatory patch path: $arg" >&2
      exit 1
    fi
  done
}

append_optional_spec() {
  local spec="$1" arg patch
  case "$spec" in
    glob:*)
      local pattern="${spec#glob:}"
      local -a matches=()
      mapfile -t matches < <(compgen -G "$pattern" | sort)
      [ "${#matches[@]}" -gt 0 ] || {
        echo "ERROR: optional patch glob matched nothing: $pattern" >&2
        exit 1
      }
      for patch in "${matches[@]}"; do
        [ -f "$patch" ] || { echo "ERROR: optional patch is not a file: $patch" >&2; exit 1; }
        optional_patches+=("$patch")
      done
      ;;
    *)
      if [ -d "$spec" ]; then
        local -a files=()
        mapfile -t files < <(find "$spec" -maxdepth 1 -type f -name '001[0-2]-*.patch' -print | sort)
        [ "${#files[@]}" -gt 0 ] || {
          echo "ERROR: no optional 0010-0012 patches in $spec" >&2
          exit 1
        }
        optional_patches+=("${files[@]}")
      elif [ -n "$spec" ]; then
        local -a words=()
        read -r -a words <<< "$spec"
        for arg in "${words[@]}"; do
          [ -f "$arg" ] || { echo "ERROR: missing optional patch: $arg" >&2; exit 1; }
          optional_patches+=("$arg")
        done
      fi
      ;;
  esac
}

append_mandatory_spec "$mandatory_spec"
[ "${#mandatory_patches[@]}" -gt 0 ] || {
  echo "ERROR: no mandatory patches selected" >&2
  exit 1
}

if [ "${HOOK_EXTRA:-lsm}" = "manual" ]; then
  [ -n "$extra_spec" ] || {
    echo "ERROR: hook_extra=manual requires an optional patch specification" >&2
    exit 2
  }
  append_optional_spec "$extra_spec"
  [ "${#optional_patches[@]}" -gt 0 ] || {
    echo "ERROR: hook_extra=manual selected no optional hooks" >&2
    exit 1
  }
  echo "hook_extra=manual: applying ${#mandatory_patches[@]} mandatory and ${#optional_patches[@]} optional patches"
else
  optional_patches=()
  echo "hook_extra=lsm: applying ${#mandatory_patches[@]} mandatory patches; optional hooks stay on the AUTO path"
fi

bash "$SCRIPT_DIR/apply-patches.sh" "$kroot" \
  "${mandatory_patches[@]}" \
  "${optional_patches[@]}"
