# cluster_failover

Exercises PacketFence cluster failover on a bootstrapped 3-node cluster.
Runs **on pf1 only** (the play targets `pf1*dev`) and observes/acts on the
peers over the root SSH set up by `addons/vagrant/playbooks/cluster_cross_ssh.yml`
(`ssh pf2`, `ssh pf3`). It runs after `cluster_verify_all`, so the cluster is
already healthy and pf1 — cluster index 0, keepalived priority `100` — holds
every VIP (`lib/pf/services/manager/keepalived.pm:106-160`).

## How failover works in a PF cluster (all VIP-driven)

keepalived owns the mgmt/reg/iso VIPs. Each interface's `vrrp_instance` has a
`track_script`:

- **mgmt / radius** interfaces track `radius_load_balancer`
  (`systemctl is-active packetfence-radiusd-load_balancer`).
- **portal (reg / iso)** interfaces track `haproxy_portal`
  (`systemctl is-active packetfence-haproxy-portal`).

When a tracked service dies, keepalived drops that instance's priority and the
VIP migrates to pf2 (priority 99). Stopping keepalived itself migrates *all*
VIPs. Preempt is on (`preempt_delay 30`), so once the service/keepalived is
restored on pf1 the VIP comes back to pf1.

Two services follow the VIP rather than being keepalived-tracked:

- **pfdhcp** only serves on the interface where it detects the VIP
  (`go/cmd/pfdhcp/main.go` `detectVIPLoop`, 3s). So DHCP failover = the reg/iso
  VIP moved → pf2's pfdhcp starts serving.
- **pfcron** only runs jobs on the node holding the **management** VIP
  (`go/cmd/pfcron/main.go` `isMaster`). So pfcron failover = the mgmt VIP moved
  → pf2 becomes the pfcron master.
- **httpd.portal** is *not* keepalived-tracked. haproxy-portal load-balances the
  portal across every node's `httpd_portal` backend (`:8080`, each with a health
  `check` — `lib/pf/services/manager/haproxy_portal.pm:89,103`). So stopping
  pf1's httpd.portal does not move the VIP; haproxy just routes to pf2/pf3 and
  the portal stays served.

## Scenario steps

- **00 — preconditions / normalize.** Start the failover-relevant services on
  every node and wait until pf1 holds all three VIPs. Self-heals a run that a
  previous (aborted) failover left half-torn-down, so the suite is re-runnable.
- **10 — keepalived failover.** `pfcmd service keepalived stop` on pf1 → all
  three VIPs migrate to pf2 → restart on pf1 → VIPs preempt back.
- **20 — RADIUS failover.** Stop `radiusd-load_balancer` on pf1 → the mgmt VIP
  migrates (reg/iso stay on pf1, scoped by track_script) → restart → back.
- **30 — haproxy-portal failover.** Stop `haproxy-portal` on pf1 → reg + iso
  VIPs migrate (mgmt stays) → restart → back.
- **40 — httpd.portal failover.** Stop `httpd.portal` on pf1 → VIP stays on pf1,
  the portal is still served through the VIP by pf2/pf3 backends → restart.
- **50 — DHCP failover.** (a) VIP-follow: move the reg/iso VIP (stop
  haproxy-portal) → pf2 owns the reg VIP and its pfdhcp is serving. (b) service
  health: stop pfdhcp on pf1, assert pf2's pfdhcp stays healthy. Restore both.
- **60 — pfcron failover.** (a) VIP-follow: move the mgmt VIP (stop
  radiusd-load_balancer) → pf2 owns the mgmt VIP and becomes pfcron master.
  (b) service health: stop pfcron on pf1, assert pf2's pfcron stays healthy.
  Restore both.
- **70 — cluster config sync.** Write a unique marker under `conf/` on pf1,
  `bin/cluster/sync --as-master --file=<marker>`, assert it propagated to
  pf2/pf3 with identical content, then delete it everywhere.

## Notes

- Service stop/start is run through `pfcmd service … || true`: several PF units
  are docker-wrapped and can exit non-zero on stop by design. The real signal is
  always the VIP/observable assertion that follows, not the action's exit code.
- VIP presence is checked with `ip -o -4 addr show | grep -qw <vip>` — interface
  independent, so it does not depend on the runtime-discovered interface names.
- Failover timing: `advert_int 5` → VIP migration lands within ~15s; track_script
  `fall 2`/`interval 5` → ~10s to trip; `preempt_delay 30` → preempt-back after
  ~30s. Assertions retry with generous windows to absorb this.
- The DHCP/pfcron "service health" halves do not themselves move a VIP (neither
  service is keepalived-tracked); they prove the standby's instance is healthy.
  The meaningful failover for both is the VIP-follow half.
