# Cache-first RADIUS answers on the connector-remote (PoC)

## Goal

Answer the MAB requests of a device the connector already knows from its local
cache instead of proxying them to PacketFence, while PacketFence stays the
source of truth: whenever a device's access may have changed, the cached reply
is dropped and the next request reaches PacketFence.

Out of scope: 802.1X/EAP (the conversation must reach PacketFence or the
credential cache), accounting (always proxied), Access-Reject (never cached).

## Decision flow on the connector (server pf-remote, authorize)

```
rewrite_calling_station_id / rewrite_called_station_id / NAS-IP-Address fill
if (!EAP-Message && !State)                 # MAB only, first packet
    rest-cachefirst  -> POST connector-cache /api/v1/radcache/lookup
    200: control:Tmp-String-1 == "cache-first"
         -> Auth-Type := Accept, no Proxy-To-Realm, reply = cached attributes
         -> post-auth: attr_filter.packetfence_post_auth, linelog "cache-first HIT"
    404 / failure: fall through
rest-remote (realm), rate limiter, proxy to PacketFence as before
post-proxy: /radcache/set on Access-Accept (unchanged)
```

`fail = 1` / `invalid = 1` on the lookup: a cache outage is a miss, never a reject.

## connector-cache (0.1.8)

- key `(mac, nas_ip, ssid)`: the reply of PacketFence depends on the switch
  (role to VLAN mapping, vendor attributes) and the SSID; the AP MAC is left
  out so roaming inside a WLAN keeps the hit. Invalidation is by MAC and
  removes every context.
- `cache_first = 0` entries (degraded mode only): written from an EAP
  conversation, carrying Session-Timeout/Termination-Action, or migrated
  from schema v1 (switch unknown). A proxied MAB Accept rewrites the entry.
- freshness: `app.cache_first_ttl` seconds since `updated_at` (set at every
  proxied Accept, i.e. PacketFence's last confirmation), default one day.
  Stale entries are a miss for cache-first but still serve degraded mode.
- `/radcache/get` (degraded) returns the best entry of the device: same
  switch and SSID, then same switch, then newest.
- counters in `/manage/stats`: CacheFirstHits/Misses/Stale/Ineligible,
  Invalidations.

## Invalidation chain

```
PacketFence hook  ->  pf::connector::radius_cache::invalidate(\@macs, %opts)
   (reevaluate_access, node_modify diff, node_delete, Nodes API, bulk updates)
   async: pfqueue job pfconnector_radius_cache_invalidate (2 s dedup per process)
   sync (ReAssignVlan / desAssociate, right before the deauth): invalidate_now
-> one POST per pfconnector server instance holding tunnels
   /api/v1/pfconnector/radius-cache-invalidate {connector_ids, macs, sync}
-> server: per-connector batcher (300 ms, 1000 MACs), or inline when sync;
   tunnelRequest POST /api/v1/radius/cache/invalidate {macs} to the connector;
   undelivered -> pending (15 min, in memory), replayed at the next handshake
-> connector: POST connector-cache /radcache/delete {"mac"} per device
```

Every remote connector is told (broadcast): a device may roam between sites
and a delete of an unknown device is free. `pfconnector.radius_cache_invalidation`
disables the hooks.

The synchronous call before the CoA/Disconnect is the ordering guarantee:
the re-authentication the deauth triggers must not be answered from the old
entry.

## Deferred

Asynchronous reporting of the cache-first answers to PacketFence (audit
log); Redis-backed pending store; targeted invalidation (connector of the
device's switch); connector-wide flush on configuration changes that alter
access without touching nodes (role to VLAN mapping, authentication rules);
history chart of the counters; a fleet-wide default pushed from PacketFence.
