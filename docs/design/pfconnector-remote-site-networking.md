# pfconnector-remote site networking: VLAN interfaces, DHCP-over-HTTPS relay, local DNS (design)

Status: in progress (phase 1 VLAN interfaces + static routes done; phase 2 DHCP-over-HTTPS in progress)
Branch context: `feature/pfconnector-site-networking` (off `clouddevel`)
Author: design notes

> Scope: let a `pfconnector-remote` host terminate one or more VLANs at a
> remote site, hold an IP on each, hand out addresses from the **cloud pfdhcp**
> to the devices in those VLANs, and answer every DNS query in those VLANs with
> the VLAN interface IP. The captive portal itself (what answers HTTP on that
> IP) is explicitly out of scope; see §11.

## 1. Problem statement

A cloud-hosted PacketFence has no layer-2 presence at the customer site. Today
the connector gives it RADIUS, Fingerbank, NTLM, credential caching and a
generic TCP/UDP tunnel, but it cannot put a device into an isolation or
registration VLAN *and* be that VLAN's DHCP and DNS server, which is what a
captive-portal flow needs.

The pieces we want on the connector host:

1. **VLAN interfaces** created on top of a physical NIC of the host
   (`eth0.100`, `eth0.101`, ...), each with a static IPv4 address, plus
   optional **static routes** (destination, gateway, interface), driven from
   the central configuration and re-applied after a reboot.
2. **DHCP relay** on those interfaces, with the lease decision made by the
   central pfdhcp so that ip4log, node registration and DHCP fingerprinting
   keep working exactly as if pfdhcp were on-site.
3. **DNS** on those interfaces that returns the interface's own IP for every
   `A` query (captive-portal DNS).

Constraints that shaped the design:

- The connector container already runs with `--network=host` but **no extra
  capabilities** (`addons/pfconnector/pfconnector-remote-combined-docker-wrapper:33`).
  There is no netlink, VLAN or IP-management code anywhere in the connector.
- All connector ↔ cloud traffic must keep going through the existing chisel
  tunnel and its connector-id authentication. No new inbound ports on the
  cloud side, no static UDP exposure of pfdhcp.
- pfdhcp in the cloud may run several replicas behind a Service.
- Desired state must live in the cloud (`connectors.conf`), not on the host.
  A re-imaged host that re-enrols with the same connector id must converge.

## 2. Core idea

Three small daemons on the connector host, one config model in the cloud, and
one new pfdhcp endpoint that speaks **DHCP wire format over HTTP**, the way
RFC 8484 does for DNS ("DoH"). pfdhcp's server logic is already a pure function
from packet-in to packet-out; only its transport is UDP-specific.

```
  Admin UI  (Configuration > Connectors > <id> > "Site networking")
     | parent NIC, VLAN id, CIDR, dhcp relay on/off, dns on/off  -> Save
     v
  connectors.conf  [<id>] interfaces=...               (pfconfig)
     |
     |  polled every 5s together with remote-binds
     v
  pfconnector-client  (in the pfconnector-remote container, host netns)
     |  GET /api/v1/pfconnector/site-network?connector-id=<id>   (through tunnel)
     |  netlink reconcile: create/modify/delete eth0.<vid>, set addr, up
     |  in-process DHCP relay listener per "dhcp" interface (chisel/share/dhcprelay)
     |  write Corefile, restart pfdns-site on change                 (phase 3)
     v
  eth0.100  10.10.100.1/24     eth0.101  10.10.101.1/24   ...
     ^                              ^
     | DHCP :67   DNS :53           |
  +--------------+  +--------------+
  | dhcprelay    |  | pfdns        |   template plugin: every A -> <vlan ip>
  +--------------+  +--------------+
     |
     |  POST http://127.0.0.1:22226/api/v1/pfconnector/dhcp-message?connector-id=<id>
     |  body: raw DHCP request (giaddr = VLAN interface IP)
     v
  pfconnector-server (cloud)  ---- giaddr must be one of the connector's "dhcp" interfaces
     |  POST <services_url.pfdhcp | http://127.0.0.1:22222>/api/v1/dhcp/message
     v
  pfdhcp  synthetic "connector" interface, ServeDHCP(srvIP = giaddr)
          -> reply bytes in the HTTP response body
```

Nothing new is exposed. The only new cloud-side listener is a route inside
pfdhcp's existing API (port 22222), reachable solely from the
pfconnector-server.

## 3. Component 1: VLAN interface management

### 3.1 Where it runs

Inside the existing `pfconnector-client` process
(`go/chisel/client/client.go`), as a reconcile loop next to the
`FETCH_REMOTES_VIA_API` poller (line ~269). It already runs in the host
network namespace, so netlink operations act on the host directly. The Go
client only reads interfaces today (`getDefaultInterfaceIPs`, ~line 377).

### 3.2 Capabilities

`--cap-add NET_ADMIN` added to `addons/pfconnector/pfconnector-remote-combined-docker-wrapper`
only. The in-cluster `sbin/pfconnector-client-docker-wrapper` (the
`local_connector` of a PacketFence server) keeps its default capabilities: it
never has interfaces configured, so its reconcile loop is a no-op and, should
it ever see some, it logs the netlink permission error and moves on. `NET_RAW`
is already in Docker's default set and is needed by the relay's layer-2
sender. No `--privileged`.

### 3.3 Reconcile algorithm (idempotent)

Library: `github.com/vishvananda/netlink` (pure Go, no `iproute2` in the image).

```
desired = site-network payload from the server (may be empty)
actual  = links whose name matches "<parent>.<vid>" AND whose alias == "pf-connector"
for d in desired.interfaces:
    link = LinkByName(d.parent + "." + d.vid)
    if missing:            LinkAdd(Vlan{Parent: parentIndex, VlanId: vid, Alias: "pf-connector"})
    if parent mismatch:    LinkDel + LinkAdd
    addrs = AddrList(link)
    if d.cidr not in addrs: AddrReplace(d.cidr); remove other pf-managed addrs
    LinkSetUp(link)
for a in actual not in desired.interfaces:
    LinkDel(a)                  # only links we created (alias check)

# static routes, all tagged with RTPROT = 201 ("pf-connector")
wanted = { (dst, gw, ifindex) for r in desired.routes }
have   = RouteListFiltered(protocol == 201)
RouteReplace(each in wanted - have); RouteDel(each in have - wanted)
```

- The `IFLA_IFALIAS` tag `pf-connector` is how we tell "ours" from a VLAN the
  operator created by hand. We never touch untagged links.
- Static routes carry a private routing protocol number (201) so we can list
  and remove exactly our own routes, never the kernel's or the operator's.
  A route may name a VLAN interface, a gateway, or both; routes whose
  interface is not yet up are retried at the next reconcile.
- Runs at start-up (covers reboot, since the container is `Restart=always`),
  then every poll when the payload's content hash changes.
- The parent NIC must already exist and be up; we do not manage it. If it is
  missing the item is reported as `error` in status (§7) and skipped.
- Failure is per-interface; one bad entry must not block the others.

### 3.4 What we deliberately do not do

- No NAT, no forwarding, no default gateway changes. Static routes are only
  what the operator asks for explicitly (typically to reach a management
  network across the VLAN). The site router remains the gateway advertised by
  DHCP option 3, which comes from the cloud `networks.conf` as today.
- No systemd-networkd/netplan/NetworkManager files on the host. Persistence is
  "re-apply on start", the same model as the rest of the connector.

## 4. Component 2: DHCP-over-HTTPS relay

### 4.1 Why not a UDP relay over the tunnel

chisel supports UDP remotes, and pfdhcp already answers relayed requests
(`findHandlerAndNetwork` matches on giaddr, `go/cmd/pfdhcp/main.go:817`) with a
`dhcp_reply_ip` option to reply to the packet source instead of giaddr. It
would work, but:

- the reply path depends on the exit node's connected UDP socket
  (`net.DialUDP`, `go/chisel/share/tunnel/tunnel_out_ssh_udp.go:189`) accepting
  a raw-socket reply that was DNAT'ed through a k8s Service;
- there is no per-connector authorization: any connector could request leases
  in any scope;
- there is no load balancing across pfdhcp replicas and no clean retry
  semantics;
- pfdhcp's REST API cannot allocate a lease (`api.go` only reads, releases and
  overrides options), so "call the API" has to mean "send the packet".

Wrapping the wire-format packet in an HTTP request removes all four issues at
the cost of one new pfdhcp handler.

### 4.2 Wire contract (mirrors RFC 8484)

```
POST /api/v1/dhcp/message
Content-Type: application/dhcp-message
X-PacketFence-Connector-Id: <id>           (set by pfconnector-server, informational)

<raw BOOTP/DHCP message, 300..1500 bytes, giaddr = VLAN interface IP>

200 OK   Content-Type: application/dhcp-message   <raw DHCP reply>
204 No Content                                    pfdhcp would have ignored it
400                                               not a parseable DHCP message
403                                               giaddr not in this connector's networks
```

No JSON, no base64: the body *is* the packet. giaddr already carries the only
routing information pfdhcp needs.

### 4.3 pfdhcp changes (`go/cmd/pfdhcp`) — implemented

1. **Route** `POST /api/v1/dhcp/message` (`api.go: handleMessage`). Parses the
   body, requires a relayed BOOTREQUEST (giaddr set), calls `ServeDHCP` on the
   synthetic interface with `srvIP = giaddr` and returns `Answer.D` (200) or
   204 when pfdhcp has nothing to say. The worker pool and its giaddr /
   source-IP / raw-socket reply logic are bypassed entirely.

2. **Scopes come from connectors.conf, not networks.conf.** Each connector
   VLAN interface with `dhcp` enabled carries its own scope (range, lease
   times, DNS, gateway, domain). `buildConnectorInterface` (`config.go`)
   translates every such interface into a `RessourseNetworkConf` (network and
   netmask from the interface CIDR, the interface address reserved out of the
   pool) and feeds the shared `buildPlainScope` helper, extracted from the
   former inline "plain network" branch so both paths build identical scopes.

3. **Synthetic interface** `Interface{Name: "connector", InterfaceType: "api"}`
   owns those scopes. It is registered in `intNametoInterface` (so the stats
   API works) but `startNetworkListeners` opens no socket for it,
   `VIP["connector"]` is set to true at start-up, and the duplicate-address
   ping in `handleDiscover` is skipped for it (`sharedutils.Ping` fatals on an
   unknown interface).

4. **Server identifier = giaddr.** `ServeDHCP` already takes a `srvIP`
   parameter that `setOptionServerIdentifier` prefers over the scope IP; the
   HTTP handler passes giaddr, so option 54 / siaddr is the connector's VLAN
   IP and unicast RENEW/REBIND land on the relay. The scope IP itself is also
   the interface address, so the option-54 check in `handleRequest` passes.

5. **`PFDHCP_DOH_ONLY=true`** (cloud): no scope is built for the local
   interfaces and no UDP listener starts; pfdhcp serves only over HTTP.
   `PFDHCP_CONNECTOR_POOL_BACKEND=mysql` shares connector leases between
   replicas.

### 4.4 pfconnector-server change (`go/chisel/server/server_handler.go`)

One more case in the switch (lines 88–157), next to `process-dhcp`:

```go
case apiPrefix + "/dhcp-message":
    s.handleDhcpMessage(w, r)
```

`handleDhcpMessage`:

- reads the connector id from the tunnel session (same source as
  `handleRemoteBinds`), never from a header sent by the client;
- parses giaddr out of the body (fixed offset 24, no full decode needed) and
  checks it is contained in one of the CIDRs of that connector's `interfaces`
  (§6.1). Anything else is `403` and a rate-limited log line. This is the
  authorization boundary that a UDP relay could never give us;
- forwards the body verbatim to `http://<pfdhcp service>:22227/api/v1/dhcp/message`
  with a 1.5 s timeout and streams the response back. Size cap 1500 bytes.

### 4.5 Relay agent on the connector host — implemented in-process

Rather than shipping standalone_dhcp as a second daemon with a generated ini,
the relay is a package inside pfconnector-client
(`go/chisel/share/dhcprelay`), modelled on standalone_dhcp's relay mode with
the UDP forward replaced by the HTTP round trip. The client's site-network
poll calls `Relay.Sync` with the VLAN interfaces flagged `dhcp` that exist on
the host; Sync starts one listener per interface (UDP/67, `SO_BINDTODEVICE`,
`SO_REUSEADDR`), stops removed ones and restarts failed ones.

Per request: set giaddr to the interface address (kept when another relay
already set it), bump hops, POST to
`http://127.0.0.1:22226/api/v1/pfconnector/dhcp-message?connector-id=<id>`,
deliver the reply per RFC 1542 §4.1.2: plain unicast to a client that sent
from its own address (renew/rebind/inform), otherwise layer-2 broadcast when
the broadcast flag is set or yiaddr is empty (NAK), otherwise a hand-built
Ethernet/IP/UDP frame to chaddr / yiaddr (the client cannot be ARPed yet).
Counters and errors per listener are exposed in `/api/v1/system/info` as
`dhcp_relay`. `PFCONNECTOR_DHCP_RELAY=false` disables it.

### 4.6 Timing rules

DHCP clients retransmit after roughly 4 s with exponential backoff. The relay
must therefore:

- use a hard HTTP timeout (1.5 s) and **drop** on timeout: the client retries,
  pfdhcp's transaction lock dedups;
- never queue behind the tunnel: a bounded worker pool (the existing 100
  workers is plenty) with no retry inside the relay;
- log tunnel-down as one line per 30 s, not per packet.

## 5. Component 3: per-VLAN DNS

pfdns is CoreDNS with the `template` plugin compiled in
(`go/cmd/pfdns/plugin.go`). No new code: the reconcile loop writes one server
block per interface with `dns=true` and restarts the `pfdns-site` s6 service:

```
.:53 {
    bind 10.10.100.1
    template IN A . {
        answer "{{ .Name }} 60 IN A 10.10.100.1"
    }
    template IN AAAA . {
        rcode NOERROR
    }
    template IN ANY . {
        rcode NXDOMAIN
    }
    log
}
```

- `bind` to the VLAN IP means the host's own resolver and the site's other
  interfaces are untouched.
- `AAAA` answers empty NOERROR so dual-stack clients do not hang on IPv6.
- The `pfdns` binary is not in the `radiusd` base image; it is copied in from
  the `pfdns` build stage in `containers/pfconnector-remote/Dockerfile`.
- Because `bind` fails if the address does not exist yet, the DNS service is
  started **after** the netlink reconcile and restarted on every interface
  change. s6 dependency: `pfdns-site` depends on `pfconnector-client`.

## 6. Configuration model

### 6.1 `connectors.conf`

New per-connector list, alongside the existing `networks`:

```ini
[site-a]
description=Site A
networks=10.10.0.0/16
interfaces=eth0:100:10.10.100.1/24:dhcp,dns , eth0:101:10.10.101.1/24:dhcp
routes=10.20.0.0/16:10.10.100.254:eth0.100 , 192.168.50.0/24::eth0.101
```

Represented in the Perl form (`lib/pfappserver/Form/Config/Connector.pm`) as
repeatable compound fields `interfaces.contains` (sub-fields `parent`,
`vlan`, `cidr`, `dhcp_relay`, `dns`) and `routes.contains` (sub-fields
`destination`, `gateway`, `interface`), serialized by the controller
(`lib/pf/UnifiedApi/Controller/Config/Connectors.pm`) to the compact strings
above. Validation: `vlan` 1–4094, `cidr` must be contained in one of the
connector's `networks`, no duplicate `(parent, vlan)` per connector, no
overlapping CIDRs across connectors; a route needs at least a gateway or an
interface, and a named interface must be one of the connector's VLAN
interfaces.

### 6.2 DHCP scope on the interface (no networks.conf change)

The DHCP scope is part of the interface row, so it stays next to the VLAN it
serves and travels with the connector:

```ini
interfaces=<<EOT
eth0.100 10.10.100.1/24 dhcp start=10.10.100.10 end=10.10.100.250 lease=300 max_lease=600 dns=8.8.8.8,8.8.4.4 gateway=10.10.100.254 domain=site.example
EOT
```

Structured form: `dhcp` (enabled/disabled), `dhcp_start`, `dhcp_end`,
`dhcp_default_lease_time`, `dhcp_max_lease_time`, `dns`, `gateway`,
`domain_name`. The form checks the range lies inside the interface's network
and excludes the interface address, and that the gateway is in the network.
pfdhcp derives network, netmask and server identifier from the interface
CIDR; nothing is declared in networks.conf.

### 6.3 Push to the connector

New server route `GET /api/v1/pfconnector/site-network?connector-id=<id>`
(`server_handler.go`), same shape and same 5 s poll as `remote-binds`:

```json
{
  "version": "sha256:…",
  "interfaces": [
    {"parent": "eth0", "vlan": 100, "cidr": "10.10.100.1/24", "dhcp_relay": true, "dns": true},
    {"parent": "eth0", "vlan": 101, "cidr": "10.10.101.1/24", "dhcp_relay": true, "dns": false}
  ],
  "routes": [
    {"destination": "10.20.0.0/16", "gateway": "10.10.100.254", "interface": "eth0.100"},
    {"destination": "192.168.50.0/24", "gateway": "", "interface": "eth0.101"}
  ]
}
```

The client acts only when `version` changes. Source of truth is pfconfig on
the server; the connector keeps nothing but the last applied payload in
`/usr/local/pf/var/conf/site-network.json` for status reporting.

## 7. Status and admin UI

- `SystemInfo` (`go/chisel/clientapi/system.go`) gains `site_network`: per
  interface `{name, state: up|down|error, addr, dhcp_relay: running|stopped,
  dns: running|stopped, error}` and per route `{destination, gateway,
  interface, state: applied|error, error}`.
- `TheStatus.vue` (`html/pfappserver/root/src/views/Configuration/connectors/_components/`)
  renders it as a small table under the existing service status.
- The connector form gets a `BaseFormGroupInterfaces.js` modelled on the
  existing `BaseFormGroupNetworks.js`.
- pfdhcp's existing `GET /api/v1/dhcp/stats/connector/<network>` works
  unchanged for the synthetic interface, so lease counts appear in the usual
  place.

## 8. Security

- **Capability surface.** `NET_ADMIN` in a host-network container is root
  over the host's networking, driven by central config that anyone with
  `CONNECTORS_UPDATE` can edit. This is comparable to the existing remote
  terminal. The reconcile loop only ever creates/deletes 802.1Q links tagged
  with our alias and routes tagged with our protocol number; it never touches
  the firewall, the default route or the parent NIC. A default route
  (`0.0.0.0/0`) is rejected at save time.
- **Authorization of DHCP.** The pfconnector-server verifies that giaddr lies
  inside the calling connector's declared `interfaces`; a compromised
  connector cannot drain another site's pool. pfdhcp itself trusts the
  `X-PacketFence-Connector-Id` header only because it is reachable solely from
  the pfconnector-server pod (NetworkPolicy to be added).
- **DHCP spoofing on the VLAN** is no different from on-site pfdhcp: rogue
  servers are outside our control, as today.
- **DNS** answers with a fixed IP only; there is no recursion, so no
  amplification vector. Rate limiting is left to CoreDNS defaults.
- **Client-side API** stays `localhostOnly`; the relay talks to
  `127.0.0.1:22226` which is the tunnel client's own port, so no new listener
  is added on the host.

## 9. Failure modes

| Failure | Behaviour |
|---|---|
| Tunnel down | Relay times out per request and drops; clients retry; DNS keeps answering locally; existing leases keep working until expiry |
| pfdhcp replica restart | Stateless HTTP path; next retransmission hits another replica; pool state is in MySQL |
| Parent NIC missing / renamed | Interface reported `error` in status, others unaffected |
| Host reboot | VLANs absent until Docker starts the container (≈ tens of seconds); reconcile recreates them, then DHCP/DNS start |
| Operator deletes an interface in the UI | Link removed at next poll; DHCP/DNS regenerated; devices already holding leases lose their gateway to us only if we were the gateway, which we are not |
| NetworkManager on the host | Externally created links are left alone by default; documented requirement that the parent NIC is not configured with `802-1x`/bridge profiles that recreate VLANs |
| Two connectors declare overlapping CIDRs | Rejected at save time (§6.1) |

## 10. Effort

| Piece | Files | Dev-days |
|---|---|---|
| Netlink reconcile loop, `NET_ADMIN`, alias tagging, status | `go/chisel/client/`, wrappers, `clientapi/system.go` | 3–4 |
| Config model: form, controller, pfconfig, `site-network` endpoint, Vue form group | `lib/pfappserver/Form/Config/Connector.pm`, `lib/pf/UnifiedApi/Controller/Config/Connectors.pm`, `server_handler.go`, Vue | 3–4 |
| pfdhcp `POST /dhcp/message`, synthetic interface, giaddr-as-server-id, `connector=` network key, tests | `go/cmd/pfdhcp/{api,config,main}.go`, networks form | 2–3 |
| pfconnector-server `dhcp-message` forward + giaddr authorization | `server_handler.go` | 1 |
| Relay agent HTTP transport, in-tree move, s6 service, ini generation | `go/cmd/pfdhcp-relay`, `containers/pfconnector-remote/` | 2 |
| pfdns in image, Corefile generation, s6 service | `containers/pfconnector-remote/` | 1–2 |
| Packaging, upgrade path, docs, staging validation | `debian/`, `Makefile`, `docs/` | 2–3 |
| **Total** | | **14–19** |

Suggested order: config model + netlink first (visible in the UI, testable
without the cloud side), then pfdhcp endpoint + server forward (testable with
`curl` and a captured DISCOVER), then the relay agent, then DNS.

## 11. Out of scope / follow-ups

- **Captive portal on the VLAN IP.** DNS returning the interface IP is only
  useful if something answers HTTP/HTTPS there. The natural next step is a
  reverse proxy in the connector container that forwards `:80/:443` on the
  VLAN IPs to the cloud portal through the tunnel, with the portal certificate
  synced the way RADIUS certs are (`sync-radius-certs`). Separate design.
- **IPv6** on the VLANs (SLAAC/DHCPv6). Not planned.
- **Option 82 / relay agent information.** Not needed, giaddr is sufficient
  for scope selection; can be added to the relay later without protocol
  changes.
- **Replacing the UDP `process-dhcp` event path.** The Fingerbank collector's
  DHCP sniffing stays as is; when the connector is the relay, pfdhcp already
  records fingerprints itself, so the two paths are redundant but harmless.

## 12. Open questions

1. Should `interfaces` live in `connectors.conf` or as a new
   `connector_interfaces.conf` with its own controller, like
   `dns_connectors.conf`? The former is simpler; the latter matches how DNS
   and domain connectors were split. Proposal: `connectors.conf`, revisit if
   the list grows other per-interface knobs.
2. Do we want the relay to also forward unicast **INFORM** and to answer
   **option 60 / PXE** locally? Default: forward everything, answer nothing
   locally.
3. Should the pfconnector-server cache the connector → CIDR map from pfconfig
   or query it per request? Per request through the existing pfconfig client
   is fine at DHCP rates; cache with a 30 s TTL if profiling says otherwise.
