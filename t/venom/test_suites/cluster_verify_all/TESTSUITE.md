# cluster_verify_all

Runs on every cluster node after `cluster_first_server` and
`cluster_joining_servers` have done their work. Asserts the cluster is
healthy per `docs/cluster/troubleshooting_a_cluster.asciidoc:78-112`.

## Requirements

- 3-node PacketFence cluster fully bootstrapped (cluster_first_server
  drove doc steps 4–10 + 13–14 on pf1; cluster_joining_servers drove
  steps 11–12 on pf2/pf3).
- All venom local vars from
  `addons/vagrant/inventory/group_vars/clusters/venom_local_vars.yml`
  rendered into `t/venom/vars/local.yml` on each node.

## Scenario steps

### 00 — wait for galera Synced
Cooldown for galera-autofix is up to 10 minutes per
`docs/cluster/understanding_the_galera_cluster_synchronization.asciidoc:136`.
We poll `wsrep_local_state_comment` until it reads `Synced`.

### 10 — galera cluster health
Asserts the canonical wsrep variables on the local node:
`wsrep_cluster_size=3`, `wsrep_cluster_status=Primary`,
`wsrep_ready=ON`, `wsrep_connected=ON`.

### 20 — PacketFence services active
Asserts `packetfence-mariadb`, `keepalived`, `radiusd-loadbalancer`
are all `active` (systemctl).

### 30 — pfcmd cluster maintenance
`/usr/local/pf/bin/pfcmd cluster maintenance` exits 0 and lists
three nodes.

## Notes

- All assertions are local-only (UNIX socket mysql, systemctl) — no
  network reachability assumed. VIP migration and portal-over-VIP checks
  live in the failover plays (`playbooks/failover.yml`), which run after this.
- mysql uses `-uroot` over the UNIX socket; no password handling
  needed (per `docs/cluster/troubleshooting_a_cluster.asciidoc:65`).
