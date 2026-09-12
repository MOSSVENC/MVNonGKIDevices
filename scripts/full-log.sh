#!/usr/bin/env bash
#
# full-log.sh — start the build's full log and make every later step append to it.
#
# Usage: full-log.sh <device-codename>
#
# Writes logs/<device>-full.log, then installs logs/bash_env.sh and points
# BASH_ENV at it. Bash sources BASH_ENV for every non-interactive shell, so the
# steps' sub-shells append to the same log. The exported DSH_FULL_LOG_HOOK
# sentinel keeps a single tee: without it each sub-shell would add another one
# and script output would appear repeatedly.
#
set -euo pipefail

dev="${1:?usage: full-log.sh <device-codename>}"
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is not set}"

mkdir -p "$GITHUB_WORKSPACE/logs"
LOG="$GITHUB_WORKSPACE/logs/$dev-full.log"
: > "$LOG"
ENVF="$GITHUB_WORKSPACE/logs/bash_env.sh"
{
  if [ -n "${BASH_ENV:-}" ]; then
    printf '[ -f %q ] && source %q\n' "$BASH_ENV" "$BASH_ENV"
  fi
  printf 'if [ -z "${DSH_FULL_LOG_HOOK:-}" ]; then\n'
  printf '  DSH_FULL_LOG_HOOK=1\n'
  printf '  export DSH_FULL_LOG_HOOK\n'
  printf '  exec > >(tee -a %q) 2>&1\n' "$LOG"
  printf 'fi\n'
} > "$ENVF"
echo "BASH_ENV=$ENVF" >> "$GITHUB_ENV"
echo "full log: $LOG"
