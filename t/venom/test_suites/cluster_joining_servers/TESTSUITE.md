# cluster_joining_servers

Runs on the second and third nodes (`pf2*dev:pf3*dev`) after
`cluster_first_server` has bootstrapped pf1 with `--force-new-cluster`. Joins
them to the cluster per `docs/cluster/cluster_setup.asciidoc` "Integrating the
two other nodes".

## Requirements

- pf1 is running `packetfence-mariadb` with `--force-new-cluster` and its
  webservices API is up (cluster_first_server).
- venom local vars: `pf1_mgmt_ip`, `cluster_webservices_user`,
  `cluster_webservices_password`.

## Scenario steps (doc-mapped)

| File | Doc step | Status |
|------|----------|--------|
| 00_stop_iptables | Stop `packetfence-iptables` | done |
| 05_register_cluster_file | Add the #8984 exec test file to this node's `cluster-files.txt` before sync | done |
| 10_cluster_sync | `cluster/sync --from=pf1`; restart packetfence-config, configreload, proxysql, httpd.webservices | done |
| 15_assert_synced_exec_perms | Assert the synced file kept its executable bit (#8984) | done |
| 20_mariadb_join | Stop mariadb, `rm -rf /var/lib/mysql/*` (guarded against pf1), restart to join | done |
| 30_assert_joined | Wait `wsrep_local_state_comment=Synced`, then `wsrep_cluster_size=3` | done |

## Notes

- The mysql flush is destructive; `20_mariadb_join` refuses to run if the
  hostname starts with `pf1`, as a guard against mis-targeting.
- `cluster_size_is_three` retries because the two joiners converge
  independently — this node can be Synced before the other has joined.
- Credentials come from `venom_local_vars.yml`, matching the `[webservices]`
  block cluster_first_server wrote into pf.conf on pf1.
- `05_register_cluster_file` + `15_assert_synced_exec_perms` are the #8984
  regression pair: they depend on `cluster_first_server/70_seed_exec_sync_file`
  having created the executable source on pf1. `05` must run before the sync
  because `cluster/sync --from` reads *this* node's `cluster-files.txt`.
  `test -x` is the discriminator — it is false when no exec bit is set (even
  for root), so it fails on the pre-fix behavior (file pulled as 0664).
