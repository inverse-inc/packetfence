# cluster_first_server

Runs on the first node (`pf1*dev`) after the `configurator` suite. Drives the
post-configurator cluster bootstrap so the first node forms a galera cluster
with `--force-new-cluster`. Maps to `docs/cluster/cluster_setup.asciidoc`.

## Requirements

- `cluster_setup_common` has run on this node (sysctl + mariadb-backup).
- `configurator` has run (or was already disabled on a re-run — the play
  guards this; services are left stopped at end of configurator).
- venom local vars present: `cluster_ip_*`, `pf{1,2,3}_{mgmt,reg,iso}_ip`,
  `cluster_webservices_*`, `cluster_galera_*`, `proxysql_*`.

## Scenario steps (doc-mapped)

| File | Doc step | Status |
|------|----------|--------|
| 00_mariadb_standalone | Ensure `packetfence-mariadb` starts standalone | done |
| 10_create_galera_user | Create `pfcluster` mysql user (@'%' + @'localhost') | done |
| 20_pf_conf_cluster_settings | pf.conf `[database]`/`[active_active]`/`[webservices]`/`[advanced]`/`[services]` + pfconfig.conf `[mysql]`; restart packetfence-config + configreload | done |
| 30_write_cluster_conf | `cluster.conf` 3-node IP map; configreload + checkup | done |
| 40_bootstrap_galera | `generatemariadbconfig`, `MARIADB_ARGS=--force-new-cluster`, start | done |
| 50_restart_pf_set_default | `pfcmd service pf restart`, `set-default packetfence-cluster`, stop iptables | done |
| 60_assert_galera_up | Assert `wsrep_on=ON`, status `Primary`, size `1` | done |
| 70_seed_exec_sync_file | Create an executable helper + register it in `cluster-files.txt` (#8984 sync-permissions coverage) | done |

## Deferred to later phases

- Steps 11–12 (sync + mariadb join) run on the joiners —
  `cluster_joining_servers`.
- "Start the first server normally" (unset `MARIADB_ARGS`, restart iptables)
  and re-enabling `galera-autofix` run **after** the joiners are integrated —
  `cluster_first_server_finalize`.
- `pfcmd service pf updatesystemd && restart` on all nodes —
  `cluster_wrapup`.
- The doc's rolling reboot is intentionally **skipped** for CI stability.

## Notes

- pf.conf blocks are appended verbatim (doc procedure); credentials come from
  `venom_local_vars.yml`, not the testcase YAML.
- cluster.conf interface names are discovered at runtime (mgmt=3/reg=4/iso=5,
  same idiom as the configurator) because the vagrant boxes use bare
  interfaces, not the doc's VLAN subinterfaces.
- configreload/checkup tolerate non-zero exits here: they warn about the DB
  being unavailable until the cluster is fully up, which the doc says to ignore.
