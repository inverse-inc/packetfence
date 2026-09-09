#!/bin/bash
# Preflight for the disk-hungry jobs: reclaim if low, else abort up front
# instead of failing mid-build with "No space left on device". CI-only.
#
# Each path is checked on its own volume, never summed: / and /var/lib are
# separate on the lab runners, so a total hides a full one behind a roomy one.
set -o nounset -o pipefail

# The reclaim wipes vagrant boxes + libvirt volumes; never do that on a dev box.
if [ -z "${CI:-}" ] && [ "${FORCE_RUNNER_DISK_RECLAIM:-}" != yes ]; then
    echo "===> not in CI -- skipping (set FORCE_RUNNER_DISK_RECLAIM=yes to override)"
    exit 0
fi

MIN_FREE_GB=${RUNNER_MIN_FREE_GB:-40}
read -r -a CHECK_PATHS <<< "${RUNNER_DISK_CHECK_PATHS:-/ /var/lib}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RECLAIM_SCRIPT=${RECLAIM_SCRIPT:-${SCRIPT_DIR}/vagrant/cleanup-runner-disk.sh}

free_gb() { df -B1G --output=avail "$1" 2>/dev/null | awk 'NR==2 {print $1+0}'; }

# Nearest existing ancestor, so df has a target for a path not created yet.
existing_ancestor() {
    local p=$1
    while [ ! -e "${p}" ] && [ -n "${p}" ]; do p=${p%/*}; done
    echo "${p:-/}"
}

# stderr: per-volume report; stdout: under-floor paths for the caller to
# capture. A path may carry its own floor as "<path>:<GB>".
below_floor() {
    local spec p floor f
    for spec in "${CHECK_PATHS[@]}"; do
        case "${spec}" in
            *:*) p=${spec%:*}; floor=${spec##*:} ;;
            *)   p=${spec};    floor=${MIN_FREE_GB} ;;
        esac
        p=$(existing_ancestor "${p}")
        f=$(free_gb "${p}")
        echo "  ${p}: ${f:-0}G free (floor ${floor}G)" >&2
        [ "${f:-0}" -lt "${floor}" ] && echo "${p}"
    done
}

# What is using a volume we could not free; "how little is left" is not enough.
report_usage() {
    local p mount
    for p in $1; do
        mount=$(df --output=target "${p}" 2>/dev/null | tail -1)
        echo "===> biggest consumers of ${mount}:" >&2
        du -xh -d1 "${mount}" 2>/dev/null | sort -h | tail -8 | sed 's/^/    /' >&2
    done
}

echo "===> runner disk preflight"
short=$(below_floor)
[ -z "${short}" ] && { echo "===> all guarded volumes above floor"; exit 0; }

echo "===> below floor on: ${short//$'\n'/ } -- reclaiming vagrant boxes, VMs and pool volumes"
if [ -x "${RECLAIM_SCRIPT}" ]; then
    "${RECLAIM_SCRIPT}" --apply || echo "WARN: reclaim non-zero" >&2
else
    echo "WARN: ${RECLAIM_SCRIPT} not executable -- skipping reclaim" >&2
fi

echo "===> free space after reclaim:"
short=$(below_floor)
if [ -n "${short}" ]; then
    report_usage "${short}"
    echo "ERROR: still below floor on: ${short//$'\n'/ } -- aborting" >&2
    exit 1
fi
