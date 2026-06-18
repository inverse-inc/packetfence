#!/bin/bash
# Reclaim disk on a gitlab-runner host that runs vagrant-libvirt PF bakes
# and tests. Safe by default: only sweeps stale/legacy artifacts, never
# the currently-active inverse-inc/pf*branch base boxes.
#
# Targets (relative to gitlab-runner $HOME, default /var/local/gitlab-runner):
#   1. Legacy 'inverse-inc/pf*dev' boxes — no -branches/-devel/-maintenance
#      suffix; pre-b42a1c6322 naming, no current pipeline references them.
#   2. Empty orphan version dirs under .vagrant.d/boxes/*/*/ (vagrant left
#      these behind after box-remove).
#   3. Vagrant Tempfiles in .vagrant.d/tmp older than $TMP_AGE_MIN (so we
#      don't yank a file an active vagrant box-add is mid-writing).
#   4. Prefetch scratch under vagrant_img_cache/* (script traps clean its
#      own dir, but a SIGKILL/OOM mid-bake leaves tmp.XXX entries behind).
#   5. libvirt-pool backing files matching the legacy pf*dev sweep above.
#
# Usage:
#   sudo ./cleanup-runner-disk.sh             # dry-run (default)
#   sudo ./cleanup-runner-disk.sh --apply     # actually clean
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
case ${1:-} in
    --apply|-y)    APPLY=yes ;;
    --dry-run|"")  APPLY=no ;;
    -h|--help)
        sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0"
        exit 0 ;;
    *)
        echo "Usage: $0 [--apply|--dry-run|-h]" >&2
        exit 2 ;;
esac

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

hdr "Disk usage before"
show_disk

hdr "Local vagrant boxes (as ${GR_USER})"
vagrant_gr box list 2>/dev/null | sed 's/^/  /' || echo "  (vagrant box list failed)"

# 1) Legacy 'inverse-inc/pf*dev' (no -<category>) boxes
hdr "Legacy 'inverse-inc/pf*dev' boxes (pre -branches/-devel/-maintenance)"
legacy=$(vagrant_gr box list --machine-readable 2>/dev/null \
    | awk -F, '$3=="box-name"{print $4}' \
    | grep -E '^inverse-inc/pf[a-z0-9]+dev$' \
    | sort -u || true)
if [ -z "${legacy}" ]; then
    echo "  (none)"
else
    echo "${legacy}" | sed 's/^/  /'
    for box in ${legacy}; do
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

# 3) Vagrant Tempfiles older than $TMP_AGE_MIN — skip outright if any
#    vagrant process is currently running, even old files could belong
#    to a long-running box-add.
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

# 5) libvirt-pool backing files for the legacy pf*dev boxes above. The
#    regex matches '...pfXXdev_vagrant_box_image_...' but NOT modern
#    '...pfXXdev-branches_vagrant_box_image_...' (the dash before the
#    version separator breaks the [a-z0-9]+ class).
hdr "libvirt-pool backing for legacy pf*dev boxes"
stale_vols=$(virsh_gr vol-list default 2>/dev/null \
    | awk '/inverse-inc-VAGRANTSLASH-pf[a-z0-9]+dev_vagrant_box_image_/{print $1}' \
    || true)
if [ -z "${stale_vols}" ]; then
    echo "  (none)"
else
    echo "${stale_vols}" | sed 's/^/  /'
    for vol in ${stale_vols}; do
        run virsh_gr vol-delete --pool default "${vol}"
    done
fi

hdr "Disk usage after"
show_disk

if [ "${APPLY}" = no ]; then
    printf '\nDry-run only. Re-run with --apply to actually clean.\n'
fi
