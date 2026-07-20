# cluster_recovery scenario

Drives full-cluster outage and ordered stop/start sequences against an existing
3-node PacketFence cluster and asserts galera recovers. Power control is done
from the Ansible controller (the runner) via libvirt (`virsh`), because a node
cannot boot itself.

This is the slow, opt-in sibling of `cluster_configurator`. It assumes a healthy
cluster already exists; the make target runs `cluster_configurator` first
(whose `cluster_already_healthy` gate skips the rebuild if the cluster is up),
then `cluster_recovery`.

## Scenarios

| ID | Name | What it does | Recovery mechanism |
|----|------|--------------|--------------------|
| A | Power failure | `virsh destroy` all 3 at once, boot all, wait | dirty-shutdown + galera-autofix seqno election |
| B | Simultaneous clean stop | clean-stop all 3 at once, boot all, wait | galera-autofix (safe_to_bootstrap is racy when simultaneous) |
| C | Sequential reboot | reboot one node at a time, re-Sync before next | quorum never lost; rejoin live primary |
| D | Wrong-order start | clean-stop 1,2,3; boot 1 then 2 (must NOT reach Primary) then 3 | `pf-mariadb` safe_to_bootstrap ordering; node 3 (last stopped) is safe |
| E | Right-order start | clean-stop 1,2,3; boot 3 first (serves alone), then 2, then 1 | node 3 bootstraps, 2 & 1 rejoin |

Each scenario ends by waiting for galera size 3 + `Synced` and running the
`cluster_verify_all` suite.

## Mechanics verified against code

- Bootstrap ordering: `sbin/pf-mariadb` (`startup_clean_shutdown`,
  `safe_to_bootstrap`, `ping_quorum`, `dirty-shutdown`).
- Autofix election: `go/cmd/galera-autofix/main.go` — waits `startWait` (5 min),
  then `handle()` tries the local DB up to `connectDBTries` (10×30s) before it
  will force-bootstrap the **highest-seqno** node; peers `bootAndRejoinCluster`
  (ForceStop → wait for peer DB → ClearAndStart/SST).
- Domain identity: `virsh --domain <uuid>`, uuid from
  `${vagrant_pf_dotfile_path}/machines/<vm>/libvirt/id` (the domain **name** is
  randomised by `addons/vagrant/Vagrantfile`). `vagrant_pf_dotfile_path` is
  passed by `test-wrapper.sh`.

## Timing note (scenario D)

D must complete each node's "not serving" check well under galera-autofix's
~10-minute intervention window (`startWait` 5m + `connectDBTries` ~5m), or
autofix would force-bootstrap the highest-seqno node and defeat the wrong-order
expectation. `not_serving_wait_seconds` is 120s per node, keeping all of D
under that window so pf-mariadb's ordering is what's exercised.

## Running

On the CI shell runner (never the workstation). Fast re-run against an
already-built cluster:

```
make -C t/venom MAKE_TARGET=run_tests cluster_recovery_deb12
```

Full build + recovery from scratch (what CI does):

```
make -C t/venom cluster_recovery_deb12
```

All six scenarios run by default. To run a subset, invoke the scenario
playbook directly with the `recovery_scenarios` extra-var (from `t/venom`,
against an already-built cluster):

```
ansible-playbook scenarios/cluster_recovery/site.yml -l <pf1,pf2,pf3> \
  -e "vagrant_pf_dotfile_path=<dotfile>" -e '{"recovery_scenarios":["D"]}'
```

(The `recovery_scenarios` list defaults to `['A','B','C','D','E','F']`.)

CI: jobs `cluster_recovery_deb12` / `_el8` run in the `test_cluster` stage under
the same `TEST_CLUSTER=yes` gate as the configurator jobs (or a `test_cluster=yes`
commit message).
