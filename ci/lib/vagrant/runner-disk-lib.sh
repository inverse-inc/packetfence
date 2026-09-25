#!/bin/bash
# Shared helpers for the runner-disk cleanup scripts (cleanup-runner-disk-var-lib
# and siblings). Sourced, never executed directly. The sourcing script must set
# APPLY (yes|no) before calling run().

run() {
    if [ "${APPLY}" = yes ]; then
        "$@"
    else
        printf 'DRY: '
        printf '%q ' "$@"; printf '\n'
    fi
}

hdr() { printf '\n=== %s\n' "$*"; }

# Refuse if the host is busy — a vagrant process for any listed user, or any
# running libvirt domain — so destructive sweeps can't yank state from a live
# VM. Args: <action-label> <user>...
assert_host_idle() {
    local label=$1; shift
    local busy= user
    for user in "$@"; do
        if pgrep -u "${user}" -af vagrant >/dev/null; then
            busy="${busy}vagrant process running as ${user}\n"
        fi
    done
    if virsh -c qemu:///system list --name 2>/dev/null | grep -q .; then
        busy="${busy}libvirt domain(s) running:\n$(virsh -c qemu:///system list --name | sed 's/^/  /')\n"
    fi
    if [ -n "${busy}" ]; then
        printf '%s refused — host is not idle:\n%b' "${label}" "${busy}" >&2
        exit 1
    fi
}
