#!/bin/bash
# build_pf_img preflight: reclaim runner disk if low, else abort before the long
# build instead of failing mid-convert with "No space left on device". CI-only:
# the purge is destructive. Guards both / and /var/lib (separate volumes on the
# lab runners: build dir + boxes on /, libvirt pool on /var/lib).
set -o nounset -o pipefail

MIN_FREE_GB=${RUNNER_MIN_FREE_GB:-40}
read -r -a CHECK_PATHS <<< "${RUNNER_DISK_CHECK_PATHS:-/ /var/lib}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RECLAIM_SCRIPT=${RECLAIM_SCRIPT:-${SCRIPT_DIR}/vagrant/cleanup-runner-disk.sh}

free_gb() { df -B1G --output=avail "$1" 2>/dev/null | awk 'NR==2 {print $1+0}'; }

# stderr: per-volume report; stdout: under-floor paths for the caller to capture.
below_floor() {
    local p f
    for p in "${CHECK_PATHS[@]}"; do
        [ -e "${p}" ] || continue
        f=$(free_gb "${p}")
        echo "  ${p}: ${f:-0}G free (floor ${MIN_FREE_GB}G)" >&2
        [ "${f:-0}" -lt "${MIN_FREE_GB}" ] && echo "${p}"
    done
}

echo "===> runner disk preflight"
short=$(below_floor)
[ -z "${short}" ] && { echo "===> all guarded volumes above floor"; exit 0; }

echo "===> below floor on: ${short//$'\n'/ } -- purging vagrant boxes and libvirt pool volumes"
if [ -x "${RECLAIM_SCRIPT}" ]; then
    # --purge is host-idle-guarded; non-zero here just means busy, so re-check.
    "${RECLAIM_SCRIPT}" --purge --apply || echo "WARN: reclaim non-zero (busy?)" >&2
else
    echo "WARN: ${RECLAIM_SCRIPT} not executable -- skipping reclaim" >&2
fi

echo "===> free space after reclaim:"
short=$(below_floor)
if [ -n "${short}" ]; then
    echo "ERROR: still below ${MIN_FREE_GB}G floor on: ${short//$'\n'/ } -- aborting" >&2
    exit 1
fi
