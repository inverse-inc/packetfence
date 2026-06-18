#!/bin/bash
# Reclaim disk on a gitlab-runner host that runs vagrant-libvirt PF bakes
# and tests. Safe by default: only sweeps stale/legacy artifacts, never
# the currently-active inverse-inc/pf*branch base boxes.
#
# Modes:
#   (default) sweep — legacy pf*dev boxes, stale Tempfiles, prefetch
#                     scratch, libvirt-pool backings for legacy boxes
#   --purge         — wipe ALL vagrant boxes, ALL .vagrant.d/tmp, ALL
#                     prefetch cache, ALL pool 'vagrant_box_image' volumes.
#                     Next pipeline re-downloads everything. Requires the
#                     runner to be idle (no vagrant proc, no running
#                     libvirt domain) — refuses otherwise.
#
# Targets (relative to gitlab-runner $HOME, default /var/local/gitlab-runner):
#   1. Vagrant boxes under .vagrant.d/boxes/ (sweep: legacy pf*dev only;
#      purge: every locally-registered box).
#   2. Empty orphan version dirs under .vagrant.d/boxes/*/*/.
#   3. Vagrant Tempfiles under .vagrant.d/tmp (sweep: >$TMP_AGE_MIN min
#      old; purge: everything).
#   4. Prefetch scratch under vagrant_img_cache/*.
#   5. libvirt-pool backing files (sweep: matching legacy pf*dev; purge:
#      every '*_vagrant_box_image_*' volume in pool 'default').
#
# Usage:
#   sudo ./cleanup-runner-disk.sh                       # dry-run sweep
#   sudo ./cleanup-runner-disk.sh --apply               # apply sweep
#   sudo ./cleanup-runner-disk.sh --purge               # dry-run purge
#   sudo ./cleanup-runner-disk.sh --purge --apply       # apply purge
#   TMP_AGE_MIN=60 sudo ./cleanup-runner-disk.sh --apply
#   GR_HOME=/srv/gl-runner sudo ./cleanup-runner-disk.sh

set -o nounset -o pipefail

GR_USER=${GR_USER:-gitlab-runner}
GR_HOME=${GR_HOME:-/var/local/gitlab-runner}
VAGRANT_HOME=${VAGRANT_HOME:-${GR_HOME}/.vagrant.d}
VAGRANT_BOXES=${VAGRANT_HOME}/boxes
VAGRANT_TMP=${VAGRANT_HOME}/tmp
PREFETCH_CACHE=${PREFETCH_CACHE:-${GR_HOME}/vagrant_img_cache}
PROVIDER=${PROVIDER:-libvirt}
TMP_AGE_MIN=${TMP_AGE_MIN:-30}

APPLY=no
PURGE=no
for arg in "$@"; do
    case "${arg}" in
        --apply|-y)    APPLY=yes ;;
        --dry-run)     APPLY=no ;;
        --purge)       PURGE=yes ;;
        -h|--help)
            sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0"
            exit 0 ;;
        *)
            echo "Usage: $0 [--apply|--dry-run] [--purge] [-h]" >&2
            exit 2 ;;
    esac
done

# Run vagrant + virsh as the gitlab-runner user (its $HOME holds the box
# store and it's the libvirt-group member that owns pool access).
if [ "$(id -un)" = "${GR_USER}" ]; then
    as_runner() { "$@"; }
else
    as_runner() { sudo -u "${GR_USER}" -H VAGRANT_HOME="${VAGRANT_HOME}" "$@"; }
fi
vagrant_gr() { as_runner vagrant "$@"; }
virsh_gr()   { as_runner virsh -c qemu:///system "$@"; }

run() {
    if [ "${APPLY}" = yes ]; then
        "$@"
    else
        printf 'DRY: '
        printf '%q ' "$@"; printf '\n'
    fi
}

hdr() { printf '\n=== %s\n' "$*"; }

show_disk() {
    df -h / /var/lib 2>/dev/null | sed 's/^/  /'
    du -sh "${VAGRANT_BOXES}" "${VAGRANT_TMP}" "${PREFETCH_CACHE}" 2>/dev/null \
        | sed 's/^/  /' || true
}

hdr "Mode: ${PURGE:+PURGE — wipes everything}${PURGE:+}${PURGE:-sweep}  Action: $([ ${APPLY} = yes ] && echo APPLY || echo dry-run)"

# Purge needs the runner idle — abort if any vagrant proc or libvirt
# domain is running, since wiping pool box images yanks backing files
# out from under live snapshot disks.
if [ "${PURGE}" = yes ]; then
    busy=
    if pgrep -u "${GR_USER}" -af vagrant >/dev/null; then
        busy="${busy}vagrant process running as ${GR_USER}\n"
    fi
    if virsh_gr list --name 2>/dev/null | grep -q .; then
        busy="${busy}libvirt domain(s) running:\n$(virsh_gr list --name | sed 's/^/  /')\n"
    fi
    if [ -n "${busy}" ]; then
        printf 'PURGE refused — runner is not idle:\n%b' "${busy}" >&2
        exit 1
    fi
fi

hdr "Disk usage before"
show_disk

hdr "Local vagrant boxes (as ${GR_USER})"
vagrant_gr box list 2>/dev/null | sed 's/^/  /' || echo "  (vagrant box list failed)"

# 1) Vagrant boxes. Sweep: legacy pf*dev only. Purge: every local box.
if [ "${PURGE}" = yes ]; then
    hdr "ALL local vagrant boxes (purge mode)"
    targets=$(vagrant_gr box list --machine-readable 2>/dev/null \
        | awk -F, '$3=="box-name"{print $4}' | sort -u || true)
else
    hdr "Legacy 'inverse-inc/pf*dev' boxes (pre -branches/-devel/-maintenance)"
    targets=$(vagrant_gr box list --machine-readable 2>/dev/null \
        | awk -F, '$3=="box-name"{print $4}' \
        | grep -E '^inverse-inc/pf[a-z0-9]+dev$' \
        | sort -u || true)
fi
if [ -z "${targets}" ]; then
    echo "  (none)"
else
    echo "${targets}" | sed 's/^/  /'
    for box in ${targets}; do
        run vagrant_gr box remove --force --all --provider "${PROVIDER}" "${box}"
    done
fi

# 2) Empty orphan version dirs left behind by past box-removes
hdr "Empty orphan version dirs under ${VAGRANT_BOXES}"
orphans=$(find "${VAGRANT_BOXES}" -mindepth 2 -maxdepth 2 -type d -empty 2>/dev/null || true)
if [ -z "${orphans}" ]; then
    echo "  (none)"
else
    echo "${orphans}" | sed 's/^/  /'
    run find "${VAGRANT_BOXES}" -mindepth 2 -maxdepth 2 -type d -empty -delete
fi

# 3) Vagrant Tempfiles. Sweep: >TMP_AGE_MIN min, and only if no vagrant
#    proc is running (even an old-looking file could belong to a long
#    box-add). Purge: everything (idle-check already enforced above).
if [ "${PURGE}" = yes ]; then
    hdr "ALL Vagrant Tempfiles under ${VAGRANT_TMP} (purge mode)"
    tmp_entries=$(find "${VAGRANT_TMP}" -mindepth 1 -maxdepth 1 2>/dev/null || true)
    if [ -z "${tmp_entries}" ]; then
        echo "  (none)"
    else
        echo "${tmp_entries}" | sed 's/^/  /'
        run find "${VAGRANT_TMP}" -mindepth 1 -delete
    fi
else
    hdr "Vagrant Tempfiles older than ${TMP_AGE_MIN}min under ${VAGRANT_TMP}"
    if pgrep -u "${GR_USER}" -af vagrant >/dev/null; then
        echo "  SKIPPED — vagrant process is running as ${GR_USER}:"
        pgrep -u "${GR_USER}" -af vagrant | sed 's/^/    /'
    else
        stale_tmp=$(find "${VAGRANT_TMP}" -mindepth 1 -mmin "+${TMP_AGE_MIN}" 2>/dev/null || true)
        if [ -z "${stale_tmp}" ]; then
            echo "  (none)"
        else
            echo "${stale_tmp}" | sed 's/^/  /'
            run find "${VAGRANT_TMP}" -mindepth 1 -mmin "+${TMP_AGE_MIN}" -delete
        fi
    fi
fi

# 4) Prefetch scratch (always safe; prefetch-base-box.sh traps clean its
#    work dir on EXIT but a crash/SIGKILL skips the trap)
hdr "Prefetch scratch under ${PREFETCH_CACHE}"
if [ -d "${PREFETCH_CACHE}" ]; then
    leftovers=$(find "${PREFETCH_CACHE}" -mindepth 1 -maxdepth 1 2>/dev/null || true)
    if [ -z "${leftovers}" ]; then
        echo "  (none)"
    else
        echo "${leftovers}" | sed 's/^/  /'
        # Restrict to direct children of PREFETCH_CACHE; don't recurse the rm.
        for entry in ${leftovers}; do
            run rm -rf "${entry}"
        done
    fi
else
    echo "  (no ${PREFETCH_CACHE})"
fi

# 5) libvirt-pool box backing files. Sweep: only legacy pf*dev matches
#    (regex pfXXdev_vagrant_box_image_; dash before _vagrant... excludes
#    modern -branches/-devel/-maintenance variants). Purge: every
#    '_vagrant_box_image_' volume in pool 'default'.
if [ "${PURGE}" = yes ]; then
    hdr "ALL libvirt-pool box backing volumes (purge mode)"
    pool_vols=$(virsh_gr vol-list default 2>/dev/null \
        | awk '/_vagrant_box_image_/{print $1}' || true)
else
    hdr "libvirt-pool backing for legacy pf*dev boxes"
    pool_vols=$(virsh_gr vol-list default 2>/dev/null \
        | awk '/inverse-inc-VAGRANTSLASH-pf[a-z0-9]+dev_vagrant_box_image_/{print $1}' \
        || true)
fi
if [ -z "${pool_vols}" ]; then
    echo "  (none)"
else
    echo "${pool_vols}" | sed 's/^/  /'
    for vol in ${pool_vols}; do
        run virsh_gr vol-delete --pool default "${vol}"
    done
fi

hdr "Disk usage after"
show_disk

if [ "${APPLY}" = no ]; then
    printf '\nDry-run only. Re-run with --apply to actually clean.\n'
fi
