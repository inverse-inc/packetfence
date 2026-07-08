# cluster_wrapup

Runs on **all** nodes (`pf[123]*dev`), **one node at a time** (`serial: 1` in
run_tests.yml), after the first node has been finalized. Maps to
`docs/cluster/cluster_setup.asciidoc` "Wrapping up".

## Scenario steps (doc-mapped)

| File | Doc step | Status |
|------|----------|--------|
| 00_updatesystemd_restart | `pfcmd service pf updatesystemd`; `pfcmd service pf restart` | done |

## Notes

- `serial: 1` restarts nodes one at a time so galera keeps quorum — the doc's
  per-node reboot intent, minus the reboot (step 16 reboot stays skipped for
  CI stability).
- This is the step that brings the cluster services (keepalived,
  radiusd-loadbalancer) active on every node; `cluster_verify_all` asserts that.
