# cluster_setup_common

Runs on **every** cluster node (`pf[123]*dev`) before the first-server
bootstrap. Covers the "Setup on all servers" section of
`docs/cluster/cluster_setup.asciidoc`.

## Scenario steps

### 00 — sysctl + db replication tools
- `/etc/sysctl.conf`: `net.ipv4.ip_nonlocal_bind = 1` (fast VIP failover)
  and `net.ipv6.conf.all.disable_ipv6 = 1`, applied with `sysctl -p`.
  The doc's `reboot` is **skipped** — `sysctl -p` applies the values live
  and reboots over the ansible connection are fragile in CI.
- Install `mariadb-backup` (+ `socat`) — required for galera SST.
  Idempotent so the suite is safe to re-run.

## Notes
- OS detection is `command -v apt-get`: Debian uses `apt-get install
  mariadb-backup socat`; EL uses `yum install MariaDB-backup socat
  --enablerepo=packetfence`.
