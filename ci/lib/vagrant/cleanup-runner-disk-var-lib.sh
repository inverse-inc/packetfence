#!/bin/bash
# Reclaim disk under /var/lib on a runner host. Covers every /var/lib
# location that grows from vagrant-libvirt PF bakes and tests, for all
# users that have relocated data, plus the host-wide libvirt state.
#
#   $VAR_LIB/<user>/.vagrant.d/        — relocated Vagrant home
#   $VAR_LIB/<user>/vagrant_img_cache/ — relocated prefetch scratch
#   /var/lib/libvirt/                  — pool images, saves, snapshots, dumps
#
# Targets every account that (a) exists in passwd and (b) has a
# $VAR_LIB/<name>/ data dir (typically gitlab-runner, plus any sibling
# runner/service account that has been relocated). The libvirt sweep
# is system-wide and runs once at the end.
#
# Modes:
#   (default) sweep — legacy pf*dev boxes, stale Tempfiles, prefetch
#                     scratch, pool backings for legacy boxes.
#   --purge         — wipe ALL vagrant boxes, ALL .vagrant.d/tmp, ALL
#                     prefetch cache, EVERY pool 'vagrant_box_image_*'
#                     volume, ALL qemu save/snapshot/dump files. Next
#                     pipeline re-downloads everything. Refuses if the
#                     host is not idle.
#
# Per-user targets (relative to $VAR_LIB/<user>/):
#   1. .vagrant.d/boxes/ (sweep: legacy pf*dev only; purge: every
#      locally-registered box).
#   2. Empty orphan version dirs under .vagrant.d/boxes/*/*/.
#   3. .vagrant.d/tmp (sweep: >$TMP_AGE_MIN min old; purge: everything).
#   4. vagrant_img_cache/* (always all entries).
#
# Global targets:
#   5. libvirt-pool $LIBVIRT_POOL backing volumes (sweep: matching
#      legacy pf*dev; purge: every '*_vagrant_box_image_*' volume).
#   6. /var/lib/libvirt/qemu/{save,snapshot,dump}/* (purge only).
#
# Usage:
#   sudo ./cleanup-runner-disk-var-lib.sh                  # dry-run sweep
#   sudo ./cleanup-runner-disk-var-lib.sh --apply          # apply sweep
#   sudo ./cleanup-runner-disk-var-lib.sh --purge          # dry-run purge
#   sudo ./cleanup-runner-disk-var-lib.sh --purge --apply  # apply purge
#   ONLY_USERS="gitlab-runner" sudo ./cleanup-runner-disk-var-lib.sh --apply
#   TMP_AGE_MIN=60 sudo ./cleanup-runner-disk-var-lib.sh --apply

set -o nounset -o pipefail

VAR_LIB=${VAR_LIB:-/var/lib}
LIBVIRT_DIR=${LIBVIRT_DIR:-/var/lib/libvirt}
LIBVIRT_POOL=${LIBVIRT_POOL:-default}
PROVIDER=${PROVIDER:-libvirt}
TMP_AGE_MIN=${TMP_AGE_MIN:-30}

APPLY=no
PURGE=no
for arg in "$@"; do
    case "${arg}" in
        --apply|-y)   APPLY=yes ;;
        --dry-run)    APPLY=no ;;
        --purge)      PURGE=yes ;;
        -h|--help)
            sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0"
            exit 0 ;;
        *)
            echo "Usage: $0 [--apply|--dry-run] [--purge] [-h]" >&2
            exit 2 ;;
    esac
done

VAGRANT_LIB_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
source "${VAGRANT_LIB_DIR}/runner-disk-lib.sh"

# Emit "user:data_dir" for every $VAR_LIB/<name>/ dir whose <name>
# resolves to a real account. ONLY_USERS filters to a subset.
discover_users() {
    local d name
    for d in "${VAR_LIB}"/*/; do
        [ -d "${d}" ] || continue
        name=$(basename "${d%/}")
        getent passwd "${name}" >/dev/null 2>&1 || continue
        if [ -n "${ONLY_USERS:-}" ]; then
            case " ${ONLY_USERS} " in
                *" ${name} "*) ;;
                *) continue ;;
            esac
        fi
        echo "${name}:${d%/}"
    done
}

# vagrant runs as the target user — VAGRANT_HOME tells it where the
# box store lives now.
as_user() {
    local user=$1 data=$2; shift 2
    if [ "$(id -un)" = "${user}" ]; then
        VAGRANT_HOME="${data}/.vagrant.d" "$@"
    else
        sudo -u "${user}" -H VAGRANT_HOME="${data}/.vagrant.d" "$@"
    fi
}

show_disk() {
    df -h / "${VAR_LIB}" 2>/dev/null | sed 's/^/  /'
    for ent in ${USERS}; do
        local data=${ent##*:}
        du -sh "${data}/.vagrant.d/boxes" "${data}/.vagrant.d/tmp" \
               "${data}/vagrant_img_cache" 2>/dev/null \
            | sed 's/^/  /' || true
    done
    du -sh "${LIBVIRT_DIR}/images" \
           "${LIBVIRT_DIR}/qemu/save" \
           "${LIBVIRT_DIR}/qemu/snapshot" \
           "${LIBVIRT_DIR}/qemu/dump" 2>/dev/null \
        | sed 's/^/  /' || true
}

clean_user_data() {
    local user=$1 data=$2
    local VAGRANT_BOXES="${data}/.vagrant.d/boxes"
    local VAGRANT_TMP="${data}/.vagrant.d/tmp"
    local PREFETCH_CACHE="${data}/vagrant_img_cache"

    hdr "User ${user} — vagrant box list"
    as_user "${user}" "${data}" vagrant box list 2>/dev/null \
        | sed 's/^/  /' || echo "  (vagrant box list failed)"

    # 1) Vagrant boxes
    local targets
    if [ "${PURGE}" = yes ]; then
        hdr "User ${user} — ALL local vagrant boxes (purge mode)"
        targets=$(as_user "${user}" "${data}" vagrant box list --machine-readable 2>/dev/null \
            | awk -F, '$3=="box-name"{print $4}' | sort -u || true)
    else
        hdr "User ${user} — legacy 'inverse-inc/pf*dev' boxes"
        targets=$(as_user "${user}" "${data}" vagrant box list --machine-readable 2>/dev/null \
            | awk -F, '$3=="box-name"{print $4}' \
            | grep -E '^inverse-inc/pf[a-z0-9]+dev$' \
            | sort -u || true)
    fi
    if [ -z "${targets}" ]; then
        echo "  (none)"
    else
        echo "${targets}" | sed 's/^/  /'
        for box in ${targets}; do
            run as_user "${user}" "${data}" vagrant box remove \
                --force --all --provider "${PROVIDER}" "${box}"
        done
    fi

    # 2) Empty orphan version dirs
    hdr "User ${user} — empty orphan version dirs under ${VAGRANT_BOXES}"
    local orphans
    orphans=$(find "${VAGRANT_BOXES}" -mindepth 2 -maxdepth 2 -type d -empty 2>/dev/null || true)
    if [ -z "${orphans}" ]; then
        echo "  (none)"
    else
        echo "${orphans}" | sed 's/^/  /'
        run find "${VAGRANT_BOXES}" -mindepth 2 -maxdepth 2 -type d -empty -delete
    fi

    # 3) Vagrant Tempfiles
    if [ "${PURGE}" = yes ]; then
        hdr "User ${user} — ALL Vagrant Tempfiles under ${VAGRANT_TMP}"
        local entries
        entries=$(find "${VAGRANT_TMP}" -mindepth 1 -maxdepth 1 2>/dev/null || true)
        if [ -z "${entries}" ]; then
            echo "  (none)"
        else
            echo "${entries}" | sed 's/^/  /'
            run find "${VAGRANT_TMP}" -mindepth 1 -delete
        fi
    else
        hdr "User ${user} — Vagrant Tempfiles older than ${TMP_AGE_MIN}min"
        if pgrep -u "${user}" -af vagrant >/dev/null; then
            echo "  SKIPPED — vagrant process is running as ${user}:"
            pgrep -u "${user}" -af vagrant | sed 's/^/    /'
        else
            local stale
            stale=$(find "${VAGRANT_TMP}" -mindepth 1 -mmin "+${TMP_AGE_MIN}" 2>/dev/null || true)
            if [ -z "${stale}" ]; then
                echo "  (none)"
            else
                echo "${stale}" | sed 's/^/  /'
                run find "${VAGRANT_TMP}" -mindepth 1 -mmin "+${TMP_AGE_MIN}" -delete
            fi
        fi
    fi

    # 4) Prefetch scratch
    hdr "User ${user} — prefetch scratch under ${PREFETCH_CACHE}"
    if [ -d "${PREFETCH_CACHE}" ]; then
        local leftovers
        leftovers=$(find "${PREFETCH_CACHE}" -mindepth 1 -maxdepth 1 2>/dev/null || true)
        if [ -z "${leftovers}" ]; then
            echo "  (none)"
        else
            echo "${leftovers}" | sed 's/^/  /'
            for entry in ${leftovers}; do
                run rm -rf "${entry}"
            done
        fi
    else
        echo "  (no ${PREFETCH_CACHE})"
    fi
}

USERS=$(discover_users)

hdr "Mode: $([ "${PURGE}" = yes ] && echo 'PURGE — wipes everything' || echo sweep)  Action: $([ "${APPLY}" = yes ] && echo APPLY || echo dry-run)"
if [ -z "${USERS}" ]; then
    echo "  No relocated user data dirs found under ${VAR_LIB} — libvirt sweep only."
else
    echo "  Detected user data dirs:"
    echo "${USERS}" | sed 's/^/    /'
fi
echo "  libvirt: ${LIBVIRT_DIR}  pool: ${LIBVIRT_POOL}"

# Purge needs the host idle — pool box-image deletes / qemu/save wipes
# would otherwise yank state out from under live VMs.
if [ "${PURGE}" = yes ]; then
    assert_host_idle PURGE $(echo "${USERS}" | cut -d: -f1)
fi

hdr "Disk usage before"
show_disk

for ent in ${USERS}; do
    clean_user_data "${ent%%:*}" "${ent##*:}"
done

# 5) libvirt-pool box backing volumes (system-wide; one sweep).
if [ "${PURGE}" = yes ]; then
    hdr "ALL libvirt-pool box backing volumes in pool '${LIBVIRT_POOL}' (purge mode)"
    pool_pat='/_vagrant_box_image_/'
else
    hdr "libvirt-pool backing for legacy pf*dev boxes in pool '${LIBVIRT_POOL}'"
    pool_pat='/inverse-inc-VAGRANTSLASH-pf[a-z0-9]+dev_vagrant_box_image_/'
fi
# Tell "no volumes" apart from "virsh failed" — a swallowed error would
# otherwise report a clean '(none)' while the volumes are left behind.
if ! pool_raw=$(virsh -c qemu:///system vol-list "${LIBVIRT_POOL}" 2>/dev/null); then
    echo "  WARNING: virsh vol-list ${LIBVIRT_POOL} failed — pool sweep skipped" >&2
    pool_raw=
fi
pool_vols=$(echo "${pool_raw}" | awk "${pool_pat}{print \$1}")
if [ -z "${pool_vols}" ]; then
    echo "  (none)"
else
    echo "${pool_vols}" | sed 's/^/  /'
    for vol in ${pool_vols}; do
        run virsh -c qemu:///system vol-delete --pool "${LIBVIRT_POOL}" "${vol}"
    done
fi

# 6) libvirt qemu save/snapshot/dump artifacts (purge only — sweep
# can't safely tell live from orphan without domain xref).
if [ "${PURGE}" = yes ]; then
    for sub in save snapshot dump; do
        dir="${LIBVIRT_DIR}/qemu/${sub}"
        hdr "libvirt qemu ${sub} files under ${dir}"
        if [ -d "${dir}" ]; then
            entries=$(find "${dir}" -mindepth 1 -maxdepth 1 2>/dev/null || true)
            if [ -z "${entries}" ]; then
                echo "  (none)"
            else
                echo "${entries}" | sed 's/^/  /'
                run find "${dir}" -mindepth 1 -delete
            fi
        else
            echo "  (no ${dir})"
        fi
    done
fi

hdr "Disk usage after"
show_disk

if [ "${APPLY}" = no ]; then
    printf '\nDry-run only. Re-run with --apply to actually clean.\n'
fi
