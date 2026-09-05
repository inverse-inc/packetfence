# pfconnector-remote high availability (active/passive, VRRP)

Status: design accepted 2026-09-05 (option 1 of the HA options review).
Branch: `feature/pfconnector-remote-ha` on top of `clouddevel` (1de28b3fdb).

## 1. Goal

A site keeps its NAC service when the connector-remote host dies: two hosts run
the connector-remote package for the **same connector** (same id and secret),
a virtual IP (VIP) moves between them with VRRP, and only the host that owns
the VIP holds the tunnel to the cloud. Switches, portal redirection and DHCP
relays are configured with the VIP, never with a host address.

Non-goals for this iteration: active/active (both hosts serving RADIUS at the
same time), replication of the local caches, multi-site connector groups.
Those are options 2 and 3 of the review and build on the same lifecycle fixes.

## 2. Facts that shape the design (clouddevel)

Server side (`go/chisel/server`):

- The SSH user name of a tunnel **is** the connector id
  (`server.go:237-250`). Two hosts with the same id both authenticate; nothing
  detects the duplicate.
- Per-connector state is keyed by id and last-writer-wins:
  `activeTunnels.Store(user.Name, tunnel)` (`server_handler.go:568`) is never
  deleted; Redis `pfconnector:activeTunnels:<id>` (`:570`) has no TTL and is
  never removed; `ips:<id>` likewise; the fingerbank reverse port is
  `23000+computeConnectorIndex(id)` so two live tunnels collide.
- `handleDynReverse` uses the stored tunnel without checking `IsActive()`
  (`server_handler.go:619`), unlike the credcache forwarder.
- The RADIUS auth/acct path only uses the *presence* of
  `PacketFence-ConnectorID`; NTLM uses its *value* (`ntlm_auth_wrapper -c`).
  Both hosts of a pair therefore look identical to the cloud, which is what
  we want.

Connector host (`addons/pfconnector`, `containers/pfconnector-remote`):

- Everything listens on the host network namespace: FreeRADIUS `*:1812/1813`,
  the tunnel binds `0.0.0.0:80/443/1815/9096`, the side-car API `:8081`.
  FreeRADIUS answers from the address a request arrived on, so a request sent
  to the VIP is answered from the VIP with no configuration change.
- `configure-raddb.sh` renders `src_ipaddr = <default-route IP>` for the
  proxy home_server `100.64.0.1:18122`; that address is only used on the
  loopback/docker0 path to the tunnel and is never seen by the NAS. It stays
  host-specific.
- EAP certificates and NAS secrets are fetched from the cloud: identical on
  both hosts. The connector-cache SQLite (`pfcc.db`), the collector DB and the
  terminal TOTP seed are per host.
- Offline "degraded" mode exists: when the tunnel is down FreeRADIUS accepts
  MAB locally, replays cached Access-Accepts and does PEAP inner auth with the
  local NTLM cache.

## 3. Design

### 3.1 Topology

```
   switches / APs / DHCP relay / portal redirect ──▶ VIP 10.0.0.250
                                                       │ VRRP (keepalived)
                          ┌────────────────────────────┴───────────────────┐
                 host A (MASTER, holds VIP)                       host B (BACKUP)
                 pfconnector-remote-combined                      pfconnector-remote-combined
                   keepalived      MASTER                           keepalived      BACKUP
                   pfconnector-client  tunnel UP ──▶ cloud           pfconnector-client  gated: no tunnel
                   radiusd-auth   remote realm                      radiusd-auth   degraded realm (idle)
                   connector-cache, fingerbank-collector            connector-cache, fingerbank-collector
```

Both hosts carry the same `conf/pfconnector-client.env` (same `AUTH`,
same `HOST`) plus the HA variables below. The cloud sees one connector.

### 3.2 keepalived, inside the combined container

keepalived runs as an s6 longrun in `pfconnector-remote-combined`, next to the
other services. The container already runs `--network=host`; the wrapper adds
`--cap-add=NET_ADMIN --cap-add=NET_BROADCAST --cap-add=NET_RAW`. Running it in
the image keeps the host footprint to the env file and follows the
"config in the image" direction of the connector-remote package.

Configuration is generated at start by the `configure-keepalived` oneshot from
the env file:

| Variable | Default | Meaning |
|---|---|---|
| `PFCONNECTOR_HA_VIP` | unset = HA off | VIP with prefix, e.g. `10.0.0.250/24` |
| `PFCONNECTOR_HA_INTERFACE` | default-route interface | interface carrying the VIP and VRRP |
| `PFCONNECTOR_HA_VRID` | `51` | VRRP virtual router id, same on both hosts |
| `PFCONNECTOR_HA_PRIORITY` | `100` | set `90` on the second host |
| `PFCONNECTOR_HA_PEER` | unset = multicast | peer host IP, switches VRRP to unicast |
| `PFCONNECTOR_HA_AUTH_PASS` | derived from the connector secret | VRRP auth, identical on both hosts by construction |

Generated `keepalived.conf` (both hosts `state BACKUP`, `nopreempt`, so a
recovered host does not take the VIP back and flap the tunnel):

```
vrrp_script chk_radiusd { script "/usr/local/pf/sbin/ha-check.sh" interval 2 weight -20 }
vrrp_instance PF_CONNECTOR {
    state BACKUP
    nopreempt
    interface <PFCONNECTOR_HA_INTERFACE>
    virtual_router_id <VRID>
    priority <PRIORITY>
    advert_int 1
    authentication { auth_type PASS  auth_pass <AUTH_PASS (8 chars)> }
    virtual_ipaddress { <VIP> }
    unicast_peer { <PEER> }            # only with PFCONNECTOR_HA_PEER
    track_script { chk_radiusd }
    notify /usr/local/pf/sbin/ha-notify.sh
}
```

`ha-check.sh` returns non-zero when FreeRADIUS is not answering on its
status port `127.0.0.1:18121`: a host whose RADIUS is broken lowers its
priority and gives the VIP away. Cloud reachability is deliberately **not**
tracked: both hosts lose it together and the degraded mode is the answer.

`ha-notify.sh` writes the VRRP state (`MASTER`/`BACKUP`/`FAULT`) to
`/usr/local/pfconnector-remote/var/run/ha_state` and logs it (the client gates
on the kernel, not on this file). On `MASTER` it also waits for the tunnel and
runs `s6-rc -u change user`, see 3.2.1.

keepalived logs to `logs/keepalived.log` through the usual s6 tee pipeline and
the file is in the admin UI log viewer allowlist.

### 3.2.1 Booting a host that does not own the VIP

The cloud-dependent oneshots (`configure-raddb`, `sync-radius-certs`,
`sync-radius-nas`, `load-fingerbank-config`) run at container start and fetch
their material through the tunnel. A backup host has no tunnel by design, so:

- `wait-for-pfconnector` returns immediately when `PFCONNECTOR_HA_VIP` is set
  and the VIP is not held, instead of waiting 60 s for port 22226.
- Each oneshot keeps the files of a previous run when the API is unreachable
  and HA is on: the rendered `sites-enabled/packetfence`, the EAP certs, the
  NAS client files, the collector env. `load-fingerbank-config` downloads to a
  temporary file so a failed fetch never truncates a working one.
- A host that never held the VIP has no such files: those oneshots fail, s6
  keeps the container running (`S6_BEHAVIOUR_IF_STAGE2_FAILS=0`) and
  FreeRADIUS does not start. When the host becomes master, `ha-notify.sh`
  waits for the tunnel (port 22226) and runs `s6-rc -u change user`, which
  retries the failed oneshots and starts FreeRADIUS and the collector. First
  failover to a never-bootstrapped host therefore costs a few extra seconds.
  Copying `raddb/`, `conf/ssl/` from the first host at install time avoids it.

### 3.3 The client only holds the tunnel while it owns the VIP

`pfconnector client` gains an HA gate driven by `PFCONNECTOR_HA_VIP`:

- Every second it checks (`net.InterfaceAddrs`) whether the VIP address is
  assigned to a local interface.
- VIP present and no tunnel: start the chisel client (connection loop, binds,
  side-car API wiring, site-network and info loops).
- VIP absent and tunnel running: close the SSH connection and stop the
  client; local tunnel binds (80, 443, 18122, 18132, ...) are released.
- Without `PFCONNECTOR_HA_VIP` the behaviour is unchanged.

The side-car API on `:8081` keeps running in both states so the admin status
panel and the terminal work on the master, and so that `radiusAuthorize`
answers `degraded` on the backup (it already does when the tunnel is nil or
inactive). `/api/v1/system/info` gains
`ha: {enabled, vip, state: master|backup, since}` for the admin UI.

The IPs reported to the cloud (`pfconnector-info`) already come from the
default-route interface, so the VIP is included on the master and is listed
first: the terminal redirect and the status panel follow the VIP.

### 3.3.1 Peer heartbeat: showing the whole group in the admin UI

The cloud only sees the master (the only host with a tunnel) and VRRP gives
the master no view of its backups (backups listen, they do not advertise). So
the backups report to the master over the site LAN: every 5 s a backup POSTs
`{hostname, version, state, priority, ts}` to `http://<VIP>:8081/api/v1/ha/heartbeat`
on the master's side-car API, signed with `X-PF-HA-Signature =
hex(HMAC-SHA256(key, body))`, `key = SHA256("pfconnector-ha-heartbeat:" +
connector secret)`; both hosts have the secret, nothing else to configure.
The master refuses bad signatures (403) and timestamps older than 60 s, and
answers 404 when HA is not enabled on it. The endpoint is not localhost-only
on purpose; everything else on 8081 stays loopback-gated.

The master keeps the last heartbeat per hostname and reports them in system
info as `ha.peers[]` with `alive = last_seen < 15 s`. The admin UI status
panel shows an "HA · <vip>" badge (warning colour when no backup is alive), a
High Availability table with the master and every peer, and a warning when no
backup is reporting. An HA badge in the connectors *list* was considered and
dropped: the list status endpoint only relays the server's connector-status
map and would need a per-connector system-info round-trip.

### 3.4 Server: same-id lifecycle made safe

These fixes are needed for HA and are correct on their own:

1. **Replace and close on duplicate.** On handshake, if `activeTunnels`
   already holds a tunnel for the id and it is still active, log
   `Connector <id> reconnected while a previous tunnel was active; closing
   the previous one` and close the previous SSH connection. The new master
   is authoritative. Its listeners (fingerbank reverse port, static remotes)
   are released when the SSH connection closes, so the new tunnel can bind
   them.
2. **Delete on close.** After `eg.Wait()`, remove the `activeTunnels` entry
   only if it still points to this tunnel (`CompareAndDelete`), delete the
   Redis instance key only if its value is this instance's address, and
   clear the dynreverse cache of the connector.
3. **Liveness before dynreverse.** `handleDynReverse` returns 404 "no active
   connector tunnel" when the stored tunnel is not active instead of binding
   a port into a dead connection.
4. **Connector status prober** already treats an inactive tunnel as down; the
   admin UI dot therefore follows the VIP owner.

Out of scope but noted: `ConnectorsContainer.ForIP` iterates a Go map and does
not honour connectors.conf order the way `pf::factory::connector::for_ip`
does. Irrelevant for a pair sharing one id, relevant for option 2.

### 3.5 Failover timeline

| Step | Time after master loss |
|---|---|
| VRRP master down detected (3 × advert_int) | ~3 s |
| Backup takes the VIP, sends gratuitous ARP | ~3 s |
| Client gate sees the VIP, connects the tunnel | ~4-5 s |
| Server replaces/cleans the stale tunnel entry, client fetches remote-binds, opens 80/443/18122/18132 | ~5-10 s |
| FreeRADIUS home_server `pf.remote` marked alive (status-server, `check_interval = 10`) | ~10-20 s |

Between the VIP move and the home_server revival the new master serves the
degraded realm: MAB accepted, EAP terminated locally with the cloud-issued
certificates, cached replies (cold on the first failover). Accounting is
acknowledged locally and lost for that window, as today when the tunnel drops.

### 3.6 Per-host state and what to copy at install

| File | Handling |
|---|---|
| `conf/pfconnector-client.env` | identical on both hosts except `PFCONNECTOR_HA_PRIORITY` (and `PFCONNECTOR_HA_PEER` when unicast) |
| `conf/terminal_totp` | copy from the first host so one enrolment QR code works for both; otherwise each host has its own seed and the admin enrols twice |
| `var/lib/packetfence-connector-cache/pfcc.db` | per host, cold on the backup; the master fills it. Sync is a later iteration |
| `db/collector_endpoints*.db` | per host, rebuilt from traffic |
| `conf/ssl`, `raddb/dynamic-clients` | fetched from the cloud at start on each host |

## 4. Implementation plan

Phase 1 – server lifecycle (`go/chisel/server`): 3.4 items 1-3, unit-testable
without a connector. Safe to ship on its own.

Phase 2 – connector host:
- `go/chisel/client` + `main.go`: HA gate (3.3), `ha` in system info. Done:
  `runHAClient` in `main.go`, `client/ha.go` (VIP parsing and presence),
  `clientapi/ha.go` (swappable tunnel, `HAStatus`), the remote-binds poll loop
  now stops with the client context. Verified on 10.0.0.251 by adding and
  removing the VIP by hand: backup → master with the binds up 5 s after the
  address appeared, tunnel closed within 1 s of its removal, second activation
  identical.
- `containers/pfconnector-remote`: `apt-get install keepalived`; s6 services
  `configure-keepalived` (oneshot) and `keepalived` (longrun, exits 0 and marks
  itself once when HA is off) with a log pipeline; `sbin/configure-keepalived.sh`,
  `ha-check.sh`, `ha-notify.sh`; bootstrap tolerance (3.7). Done, untested on a
  real image build.
- `addons/pfconnector`: wrapper capabilities; `configure.sh` asks for the VIP,
  interface, priority and peer and writes the `PFCONNECTOR_HA_*` variables. Done.

Phase 3 – admin UI and docs: peer heartbeat (3.3.1) and HA block in the
connector status panel (`TheStatus.vue`), VIP shown as the address to
configure on switches; several unicast peers (`PFCONNECTOR_HA_PEER` is a
comma-separated list); `docs/installation/pfconnector.asciidoc` section
"High availability" written from the failover test.

Phase 4 (later) – warm caches: periodic copy of `pfcc.db` and the NT-key cache
to the peer over the LAN, or cloud-side push to every tunnel of the id when
option 3 lands.

## 5. Test results

Single host, 2026-09-05, image built from this branch on 10.0.0.251 with the
clouddevel base images (`packetfence/pfconnector-remote-combined:ha-test`,
kept on the host), `PFCONNECTOR_HA_VIP=10.0.0.250/24`:

- keepalived starts from the generated config, becomes MASTER, adds the VIP
  and sends gratuitous ARPs; `ha_state` = MASTER; the client connects the
  tunnel within a second of the VIP and the binds follow 5 s later.
- All services up on a host that booted without tunnel, i.e. the cached
  fallbacks and the MASTER notify hook work.
- `ha-check.sh` healthy after adding the Message-Authenticator to the
  Status-Server probe (radclient sends nothing on an empty body).
- Heartbeat: a valid signed heartbeat is accepted and shows in `ha.peers`
  (alive, then not alive 15 s later); a bad signature is refused with 403.
  The admin status API on akadev relays `system.ha` with the peers.
- `s6-svc -d keepalived`: VIP removed, tunnel stopped within 1 s;
  `s6-svc -u`: MASTER again, tunnel and binds back within 6 s.

Lesson: s6 oneshot `up` scripts run without the container environment, so
every script that needs `PFCONNECTOR_HA_*` sources
`/usr/local/pf/sbin/pfconnector-env.sh`, which loads pfconnector-client.env.

Still to run: the two-host failover (5.1) once a second VM is available.

## 5.1 Test plan (two hosts)

- Two VMs on one L2 (e.g. the existing 10.0.0.251 plus a clone), VIP
  10.0.0.250, a switch or `radclient` pointed at the VIP.
- Stop the master container: VIP moves, tunnel re-established from the
  backup within ~5 s, admin UI status stays green, RADIUS auth through the VIP
  succeeds after the home_server revives; degraded answers in between.
- Start the old master again: with `nopreempt` it stays backup, no second
  tunnel appears (server log shows no "closing the previous one" line).
- Kill FreeRADIUS on the master only: `chk_radiusd` drops the priority, VIP
  and tunnel move.
- Duplicate install without VRRP (misconfiguration): both hosts flap the
  tunnel every reconnect; the server log makes it visible.
