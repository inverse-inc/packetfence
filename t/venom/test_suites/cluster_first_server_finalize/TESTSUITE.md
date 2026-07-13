# cluster_first_server_finalize

Runs on the first node (`pf1*dev`) **after** `cluster_joining_servers` has
integrated pf2/pf3. Brings pf1 out of the bootstrap state. Maps to
`docs/cluster/cluster_setup.asciidoc` "Starting the first server normally" +
"Enabling galera-autofix service".

## Requirements

- pf2/pf3 have joined and hold the cluster (so pf1 can drop
  `--force-new-cluster` without losing quorum).

## Scenario steps (doc-mapped)

| File | Doc step | Status |
|------|----------|--------|
| 00_mariadb_normal | Stop mariadb, `unset-environment MARIADB_ARGS`, start normally, wait Synced | done |
| 10_iptables_and_galera_autofix | `restart packetfence-iptables`; re-enable `galera-autofix` via `localhost:22224/api/v1/config/base/services` | done |

## Notes

- galera-autofix was disabled during bootstrap (cluster_first_server pf.conf
  `[services]`); this re-enables it once the cluster is healthy.
