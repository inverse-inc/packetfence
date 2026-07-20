#!/bin/bash
# Reclaim disk on a runner host that runs vagrant-libvirt PF bakes and
# tests. Safe by default: only sweeps stale/legacy artifacts, never the
# currently-active inverse-inc/pf*branch base boxes.
#
# Targets every user account whose $HOME sits under /var/local/<name>
# (e.g. gitlab-runner, plus any sibling runner/service account). The
# libvirt pool sweep is system-wide and runs once at the end.
#
# Modes:
#   (default) sweep — legacy pf*dev boxes, stale Tempfiles, prefetch
#                     scratch, libvirt-pool backings for legacy boxes
#   --purge         — wipe ALL vagrant boxes, ALL .vagrant.d/tmp, ALL
#                     prefetch cache, ALL pool 'vagrant_box_image' volumes.
#                     Next pipeline re-downloads everything. Requires the
#                     host to be idle (no vagrant proc on any tracked
#                     user, no running libvirt domain) — refuses otherwise.
#
# Per-user targets (relative to each detected $HOME):
#   1. Vagrant boxes under .vagrant.d/boxes/ (sweep: legacy pf*dev only;
#      purge: every locally-registered box).
#   2. Empty orphan version dirs under .vagrant.d/boxes/*/*/.
#   3. Vagrant Tempfiles under .vagrant.d/tmp (sweep: >$TMP_AGE_MIN min
#      old; purge: everything).
#   4. Prefetch scratch under $HOME/vagrant_img_cache/*.
#
# Global target:
#   5. libvirt-pool backing files in pool 'default' (sweep: matching
#      legacy pf*dev; purge: every '*_vagrant_box_image_*' volume).
#
# Usage:
#   sudo ./cleanup-runner-disk.sh                       # dry-run sweep
#   sudo ./cleanup-runner-disk.sh --apply               # apply sweep
#   sudo ./cleanup-runner-disk.sh --purge               # dry-run purge
#   sudo ./cleanup-runner-disk.sh --purge --apply       # apply purge
#   ONLY_USERS="gitlab-runner" sudo ./cleanup-runner-disk.sh --apply
#   TMP_AGE_MIN=60 sudo ./cleanup-runner-disk.sh --apply

set -o nounset -o pipefail

VAR_LOCAL=${VAR_LOCAL:-/var/local}
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

run() {
    if [ "${APPLY}" = yes ]; then
        "$@"
    else
        printf 'DRY: '
        printf '%q ' "$@"; printf '\n'
    fi
}

hdr() { printf '\n=== %s\n' "$*"; }

# True if user $1 runs the vagrant CLI. Match the executable, not the substring:
# plain -f vagrant also hits paths like ci/lib/vagrant/ and vim on *vagrant* files.
VAGRANT_PROC_RE='(^|[ /])vagrant( |$)'
vagrant_running() { pgrep -u "$1" -af "${VAGRANT_PROC_RE}"; }

# Emit "user:home" lines for every $VAR_LOCAL/<name> dir whose <name>
# resolves to a real account whose $HOME equals the dir. Filter with
# ONLY_USERS="a b c" if you want a subset.
discover_users() {
    local d name pw home
    for d in "${VAR_LOCAL}"/*/; do
        [ -d "${d}" ] || continue
        name=$(basename "${d%/}")
        pw=$(getent passwd "${name}" 2>/dev/null) || continue
        home=$(echo "${pw}" | cut -d: -f6)
        [ "${home}" = "${d%/}" ] || continue
        if [ -n "${ONLY_USERS:-}" ]; then
            case " ${ONLY_USERS} " in
                *" ${name} "*) ;;
                *) continue ;;
            esac
        fi
        echo "${name}:${home}"
    done
}

# vagrant + virsh run as the target user (its $HOME holds the box store
# and it's the libvirt-group member that owns pool access).
as_user() {
    local user=$1 home=$2; shift 2
    if [ "$(id -un)" = "${user}" ]; then
        VAGRANT_HOME="${home}/.vagrant.d" "$@"
    else
        sudo -u "${user}" -H VAGRANT_HOME="${home}/.vagrant.d" "$@"
    fi
}

show_disk() {
    df -h / /var/lib 2>/dev/null | sed 's/^/  /'
    for ent in ${USERS}; do
        local user=${ent%%:*} home=${ent##*:}
        du -sh "${home}/.vagrant.d/boxes" "${home}/.vagrant.d/tmp" \
               "${home}/vagrant_img_cache" 2>/dev/null \
            | sed 's/^/  /' || true
    done
}

# Per-user cleanup steps 1-4. Step 5 (libvirt pool) is global.
clean_user_home() {
    local user=$1 home=$2
    local VAGRANT_BOXES="${home}/.vagrant.d/boxes"
    local VAGRANT_TMP="${home}/.vagrant.d/tmp"
    local PREFETCH_CACHE="${home}/vagrant_img_cache"

    hdr "User ${user} — vagrant box list"
    as_user "${user}" "${home}" vagrant box list 2>/dev/null \
        | sed 's/^/  /' || echo "  (vagrant box list failed)"

    # 1) Vagrant boxes
    local targets
    if [ "${PURGE}" = yes ]; then
        hdr "User ${user} — ALL local vagrant boxes (purge mode)"
        targets=$(as_user "${user}" "${home}" vagrant box list --machine-readable 2>/dev/null \
            | awk -F, '$3=="box-name"{print $4}' | sort -u || true)
    else
        hdr "User ${user} — legacy 'inverse-inc/pf*dev' boxes"
        targets=$(as_user "${user}" "${home}" vagrant box list --machine-readable 2>/dev/null \
            | awk -F, '$3=="box-name"{print $4}' \
            | grep -E '^inverse-inc/pf[a-z0-9]+dev$' \
            | sort -u || true)
    fi
    if [ -z "${targets}" ]; then
        echo "  (none)"
    else
        echo "${targets}" | sed 's/^/  /'
        for box in ${targets}; do
            run as_user "${user}" "${home}" vagrant box remove \
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
        if vagrant_running "${user}" >/dev/null; then
            echo "  SKIPPED — vagrant process is running as ${user}:"
            vagrant_running "${user}" | sed 's/^/    /'
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
if [ -z "${USERS}" ]; then
    echo "No user homes discovered under ${VAR_LOCAL} — nothing to do." >&2
    exit 0
fi

hdr "Mode: $([ "${PURGE}" = yes ] && echo 'PURGE — wipes everything' || echo 'sweep')  Action: $([ ${APPLY} = yes ] && echo APPLY || echo dry-run)"
echo "  Detected user homes:"
echo "${USERS}" | sed 's/^/    /'

# Purge needs the host idle — abort if any tracked user has a running
# vagrant proc or any libvirt domain is up. Pool box-image deletes would
# otherwise yank backing files out from under live snapshots.
if [ "${PURGE}" = yes ]; then
    busy=
    for ent in ${USERS}; do
        user=${ent%%:*}
        if vagrant_running "${user}" >/dev/null; then
            busy="${busy}vagrant process running as ${user}\n"
        fi
    done
    if virsh -c qemu:///system list --name 2>/dev/null | grep -q .; then
        busy="${busy}libvirt domain(s) running:\n$(virsh -c qemu:///system list --name | sed 's/^/  /')\n"
    fi
    if [ -n "${busy}" ]; then
        printf 'PURGE refused — host is not idle:\n%b' "${busy}" >&2
        exit 1
    fi
fi

hdr "Disk usage before"
show_disk

for ent in ${USERS}; do
    clean_user_home "${ent%%:*}" "${ent##*:}"
done

# 5) libvirt-pool box backing files (system-wide; one sweep).
if [ "${PURGE}" = yes ]; then
    hdr "ALL libvirt-pool box backing volumes (purge mode)"
    pool_vols=$(virsh -c qemu:///system vol-list default 2>/dev/null \
        | awk '/_vagrant_box_image_/{print $1}' || true)
else
    hdr "libvirt-pool backing for legacy pf*dev boxes"
    pool_vols=$(virsh -c qemu:///system vol-list default 2>/dev/null \
        | awk '/inverse-inc-VAGRANTSLASH-pf[a-z0-9]+dev_vagrant_box_image_/{print $1}' \
        || true)
fi
if [ -z "${pool_vols}" ]; then
    echo "  (none)"
else
    echo "${pool_vols}" | sed 's/^/  /'
    for vol in ${pool_vols}; do
        run virsh -c qemu:///system vol-delete --pool default "${vol}"
    done
fi

hdr "Disk usage after"
show_disk

if [ "${APPLY}" = no ]; then
    printf '\nDry-run only. Re-run with --apply to actually clean.\n'
fi
