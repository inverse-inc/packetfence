#!/bin/bash
# Reclaim runner disk: every vagrant box, prefetch archive, Tempfile, libvirt
# box_image volume and vagrant-* domain, for each $HOME under /var/local/<user>.
# Boxes come back from Linode next pipeline and test-wrapper.sh rebuilds any VM
# it cannot boot, so nothing here is worth keeping. Runners hold one job at a
# time; a second concurrent job would lose its boxes and VMs to this.
#
# Usage: [--apply]                  dry-run unless --apply
#   ONLY_USERS="gitlab-runner" sudo ./cleanup-runner-disk.sh --apply

set -o nounset -o pipefail

VAR_LOCAL=${VAR_LOCAL:-/var/local}
VIRSH_URI=${VIRSH_URI:-qemu:///system}

# Our own account, defaulted here and not in a caller: /var/local holds people's
# homes, and naming them in a job log of a public project is a disclosure. Set
# ONLY_USERS deliberately to widen it.
ONLY_USERS=${ONLY_USERS:-$(id -un)}

APPLY=no
for arg in "$@"; do
    case "${arg}" in
        --apply|-y)    APPLY=yes ;;
        --dry-run)     APPLY=no ;;
        -h|--help)
            sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0"
            exit 0 ;;
        *)
            echo "Usage: $0 [--apply|--dry-run] [-h]" >&2
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

virsh_sys() { virsh -c "${VIRSH_URI}" "$@"; }

# Emit "user:home" lines for every $VAR_LOCAL/<name> dir whose <name>
# resolves to a real account whose $HOME equals the dir. Filter with
# ONLY_USERS="a b c" if you want a subset, or USER_HOMES to bypass discovery.
discover_users() {
    local d name pw home
    if [ -n "${USER_HOMES:-}" ]; then
        local -a homes
        read -ra homes <<< "${USER_HOMES}"
        printf '%s\n' "${homes[@]}"
        return
    fi
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

# df only: du would walk tens of GB of images to report what free space says.
show_disk() { df -h / /var/lib 2>/dev/null | sed 's/^/  /'; }

# Print what find(1) matches, then delete it. A missing dir matches nothing.
clean_find() {
    local label=$1; shift
    hdr "${label}"
    local hits
    hits=$(find "$@" 2>/dev/null || true)
    if [ -z "${hits}" ]; then
        echo "  (none)"
    else
        echo "${hits}" | sed 's/^/  /'
        run find "$@" -delete
    fi
}

# "<name>,<provider>" per registered box; the provider keeps `box remove` from
# failing on a box registered for something other than libvirt.
box_entries() {
    local user=$1 home=$2 out
    if ! out=$(as_user "${user}" "${home}" vagrant box list --machine-readable 2>&1); then
        echo "WARN: vagrant box list failed for ${user}: ${out}" >&2
        return 1
    fi
    printf '%s\n' "${out}" \
        | awk -F, '$3=="box-name"{n=$4} $3=="box-provider" && n!=""{print n","$4}' \
        | sort -u
}

# No libvirt access looks exactly like an empty host, so say which it was.
virsh_or_warn() {
    local out
    if ! out=$(virsh_sys "$@" 2>&1); then
        echo "WARN: virsh $* failed: ${out}" >&2
        return 1
    fi
    printf '%s\n' "${out}"
}

# vol-list has no --name, so parse the table (two header lines). Asking for a
# flag it does not support is what made this step report "(none)" against 71G.
pools() { virsh_or_warn pool-list | awk 'NR>2 && $1 {print $1}'; }

pool_vol_names() { virsh_or_warn vol-list --pool "$1" | awk 'NR>2 && $1 {print $1}'; }

# destroy first: undefine --remove-all-storage refuses a running domain
force_undefine_domain() {
    virsh_sys destroy --domain "$1" >/dev/null 2>&1 || true
    virsh_sys undefine --domain "$1" --remove-all-storage
}

# Accounts with a home under $VAR_LOCAL other than ours. DOMAIN_PREFIX falls
# back to $USER, so vagrant-<acct>-* is a person's VM and not ours to destroy.
list_local_accounts() {
    local d name pw
    for d in "${VAR_LOCAL}"/*/; do
        [ -d "${d}" ] || continue
        name=$(basename "${d%/}")
        pw=$(getent passwd "${name}" 2>/dev/null) || continue
        [ "$(echo "${pw}" | cut -d: -f6)" = "${d%/}" ] || continue
        [ "${name}" = "$(id -un)" ] || echo "${name}"
    done
}

# Their name stays out of the log too: CI logs are as public as the project.
owned_by_person() {
    local acct
    for acct in ${PROTECTED_ACCOUNTS}; do
        case "$1" in "vagrant-${acct}-"*) return 0 ;; esac
    done
    return 1
}

# The Vagrantfile names domains vagrant-<CI_COMMIT_REF_SLUG>-* in CI and
# vagrant-<user>-* elsewhere, so only on a CI runner is a slug-named domain ours.
is_ours() {
    owned_by_person "$1" && return 1
    [ -z "${CI:-}" ] || return 0
    case "$1" in "vagrant-$(id -un)-"*) return 0 ;; esac
    return 1
}

# Volume names the domains' disks use, plus the box images backing them.
# Non-zero when any query fails, so callers can fail closed.
domain_volume_names() {
    local dom src xml blk
    for dom in "$@"; do
        blk=$(virsh_or_warn domblklist --domain "${dom}") || return 1
        for src in $(echo "${blk}" | awk 'NR>2 && $2 ~ /^\// {print $2}'); do
            basename "${src}"
            xml=$(virsh_or_warn vol-dumpxml --vol "${src}") || return 1
            echo "${xml}" | sed -n '/<backingStore>/,/<\/backingStore>/s|.*<path>\(.*\)</path>.*|\1|p' \
                | xargs -r -n1 basename
        done
    done
}

clean_user_home() {
    local user=$1 home=$2 entry
    local VAGRANT_BOXES="${home}/.vagrant.d/boxes"
    local VAGRANT_TMP="${home}/.vagrant.d/tmp"
    local PREFETCH_CACHE="${home}/vagrant_img_cache"

    # 1) Vagrant boxes, ours and public alike
    hdr "User ${user} — ALL local vagrant boxes"
    local entries
    entries=$(box_entries "${user}" "${home}")
    if [ -z "${entries}" ]; then
        echo "  (none)"
    else
        echo "${entries}" | sed 's/^/  /'
        for entry in ${entries}; do
            run as_user "${user}" "${home}" vagrant box remove \
                --force --all --provider "${entry##*,}" "${entry%%,*}"
        done
    fi

    # 2) Empty orphan version dirs
    clean_find "User ${user} — empty orphan version dirs under ${VAGRANT_BOXES}" \
        "${VAGRANT_BOXES}" -mindepth 2 -maxdepth 2 -type d -empty

    # 3) Vagrant Tempfiles
    clean_find "User ${user} — ALL Vagrant Tempfiles under ${VAGRANT_TMP}" \
        "${VAGRANT_TMP}" -mindepth 1

    # 4) Prefetch scratch: dropping a version marker only costs a re-download
    clean_find "User ${user} — prefetch scratch under ${PREFETCH_CACHE}" \
        "${PREFETCH_CACHE}" -mindepth 1
}

PROTECTED_ACCOUNTS=${PROTECTED_ACCOUNTS:-$(list_local_accounts)}

USERS=$(discover_users)
if [ -z "${USERS}" ]; then
    echo "No user homes discovered under ${VAR_LOCAL} — nothing to do." >&2
    exit 0
fi

hdr "Action: $([ "${APPLY}" = yes ] && echo APPLY || echo dry-run)"
echo "  Detected user homes:"
echo "${USERS}" | sed 's/^/    /'

hdr "Disk usage before"
show_disk

for ent in ${USERS}; do
    clean_user_home "${ent%%:*}" "${ent##*:}"
done

# A running domain is a live job: its overlay and the box image under it both
# have to survive, so skip the whole pool instead of picking volumes apart.
# A failed libvirt query is not an empty host, so it skips too.
reclaim_domains_and_volumes() {
    local running all live dom pool vol ours= kept= skipped=0 found=no
    if ! running=$(virsh_or_warn list --state-running --name); then
        hdr "Vagrant domains and pool volumes"
        echo "  SKIPPED — libvirt query failed, host state unknown"
        return 0
    fi
    live=$(echo "${running}" | grep -c '^vagrant-' || true)
    if [ "${live}" -gt 0 ]; then
        hdr "Vagrant domains and pool volumes"
        echo "  SKIPPED — ${live} live vagrant domain(s), another job is using them"
        return 0
    fi
    if ! all=$(virsh_or_warn list --all --name); then
        hdr "Vagrant domains and pool volumes"
        echo "  SKIPPED — libvirt query failed, host state unknown"
        return 0
    fi

    # 5) Vagrant domains and their disks
    hdr "Vagrant domains"
    for dom in $(echo "${all}" | grep '^vagrant-' || true); do
        if is_ours "${dom}"; then
            ours="${ours} ${dom}"
        else
            kept="${kept} ${dom}"
            skipped=$((skipped + 1))
        fi
    done
    [ "${skipped}" -eq 0 ] || echo "  (left ${skipped} domain(s) not attributable to this runner)"

    # Their disks, and the box images those sit on, must outlive the sweep below.
    local spared
    if ! spared=$(domain_volume_names ${kept}); then
        echo "  SKIPPED — cannot resolve volumes of preserved domains"
        return 0
    fi

    if [ -z "${ours}" ]; then
        echo "  (none)"
    else
        for dom in ${ours}; do
            echo "  ${dom}"
            run force_undefine_domain "${dom}"
        done
    fi

    # 6) libvirt-pool box backing files, across every pool
    hdr "libvirt-pool box backing volumes"
    for pool in $(pools); do
        for vol in $(pool_vol_names "${pool}" | grep -F '_vagrant_box_image_' || true); do
            if echo "${spared}" | grep -qxF "${vol}"; then
                continue
            fi
            found=yes
            echo "  ${pool}/${vol}"
            run virsh_sys vol-delete --pool "${pool}" "${vol}"
        done
    done
    [ "${found}" = yes ] || echo "  (none)"
}

reclaim_domains_and_volumes

hdr "Disk usage after"
show_disk

if [ "${APPLY}" = no ]; then
    printf '\nDry-run only. Re-run with --apply to actually clean.\n'
fi
