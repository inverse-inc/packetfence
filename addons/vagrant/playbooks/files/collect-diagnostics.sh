#!/bin/bash
# System diagnostics for a test VM, written where the Venom log archive picks
# them up. Runs at teardown on every reachable VM, including runs that failed
# before Venom started - that's when these are the only logs we get.
set -o nounset -o pipefail

OUT_DIR=${1:-/usr/local/pf/t/venom/results/diagnostics-$(hostname -s)}
mkdir -p "${OUT_DIR}"

# Every command is bounded: teardown has a 6m budget shared with sanitization
# and the log fetch.
dump() {
    local name=$1; shift
    command -v "$1" >/dev/null 2>&1 || return 0
    timeout 60 "$@" > "${OUT_DIR}/${name}.txt" 2>&1
    echo "  ${name}.txt ($(wc -c < "${OUT_DIR}/${name}.txt") bytes)"
}

echo "=== collect-diagnostics on $(hostname) at $(date '+%F %T %Z') ==="

dump os-release cat /etc/os-release
dump uname uname -a
dump uptime uptime
dump df df -h
dump free free -m
dump ps ps auxf
dump ip-addr ip -d addr
dump ip-route ip route show table all
dump listening-sockets ss -lntup
dump iptables iptables-save
dump hosts cat /etc/hosts
dump resolv-conf cat /etc/resolv.conf

dump systemd-failed systemctl --no-pager --failed
dump systemd-units systemctl --no-pager --all list-units
dump packetfence-units systemctl --no-pager --all list-units 'packetfence*'

# '-b -1' is the reason this file exists when a VM never came back from a reboot
dump journal-current-boot journalctl --no-pager --no-hostname -b -n 200000
dump journal-previous-boot journalctl --no-pager --no-hostname -b -1 -n 200000
dump dmesg dmesg -T

if [ -x /usr/local/pf/bin/pfcmd ]; then
    dump pf-service-status /usr/local/pf/bin/pfcmd service pf status
fi
# no pf.conf here: it holds the database password and artifacts are public
for conf in cluster.conf networks.conf; do
    if [ -f "/usr/local/pf/conf/${conf}" ]; then
        dump "conf-${conf%.conf}" cat "/usr/local/pf/conf/${conf}"
    fi
done

# cluster runs live or die on Galera state
if command -v mysql >/dev/null 2>&1; then
    timeout 60 mysql -uroot -e "SHOW STATUS LIKE 'wsrep_%'" \
            > "${OUT_DIR}/galera-status.txt" 2>&1
    echo "  galera-status.txt"
fi

echo "=== collect-diagnostics done, wrote to ${OUT_DIR} ==="
exit 0
