# cluster_joiners_resync

Runs on `pf2*dev:pf3*dev` after `cluster_first_server_finalize`, before
`cluster_wrapup`.

Finalize re-enables `galera-autofix` on pf1 only. Without this resync, pf1's
first `pfcmd` run in wrap-up reverts it from the joiners' quorum, autofix stays
disabled everywhere and recovery B never bootstraps.

| File | Step |
|------|------|
| 00_resync_from_first_server | `cluster/sync --from=pf1`, assert autofix is not disabled |

Needs the same venom local vars as `cluster_joining_servers`.
