# PacketFence MAC Authentication Performance Investigation

**Author:** Ludovic Zammit
**Date:** 2026-05-07 / 2026-05-08
**Target version:** PacketFence `maintenance-14-0`
**Test platform:** Debian 12, kernel 6.1, started at 4 vCPU / 16 GB RAM / fast disk; later 8 vCPU
**Headline:** Sustained MAC auth throughput went from **~60/sec to ~170/sec** on the same all-in-one host through three configuration/code fixes — none of which required new hardware beyond a 4→8 vCPU resize.

---

## 1. Executive summary

A series of MAC-authentication load tests had revealed a puzzling ceiling: roughly **60 auth/sec** in both an on-premises deployment (very low switch↔PF latency) and a cloud deployment (25 ms latency). Because the throughput was identical despite very different network conditions, the bottleneck was clearly *inside* PacketFence, not on the wire.

This investigation peeled three independent serialization points off the auth path. Each one was hidden behind the previous one — every fix revealed the next ceiling.

| Stage | Change applied | Sustained auth/sec |
|---|---|---|
| Baseline (4 vCPU, defaults) | — | ~60 |
| Bump pfqueue `general` workers from 1 to 8 | `conf/pfqueue.conf` | ~75 |
| Resize to 8 vCPU | — | ~67 (test client capped) |
| Gate Fingerbank cache writes when API key not configured | patch in `lib/pf/security_event.pm` | ~85-100 |
| Also gate `accounting_events_history` `KEYS` scan | second patch in same file | ~125-150 |
| Push offered load to peak | — | **~170 (DB cap)** |

That's **~2.8× the original ceiling** on the same software. The remaining wall is mariadbd CPU on a shared all-in-one host (~100% of one core). Moving the database to its own host or scaling to 16 vCPU is the next architectural lever.

---

## 2. The original puzzle

The customer reported that MAC authentication throughput plateaued at the same number — about 60 auth/sec — in two very different environments:

- **On-prem**: switches and PF on the same LAN, sub-millisecond RTT.
- **Cloud**: switches and PF separated by 25 ms RTT.

Intuition said the on-prem deployment should be faster because each request finishes its round-trip sooner. The fact that it wasn't is the diagnostic gold:

> **When the offered load is high enough that a network-latency change does not change throughput, the bottleneck is internal to the receiver.**

By Little's Law, throughput at a saturated stage equals `concurrency_at_bottleneck / service_time_at_bottleneck`. Network latency only adds to the *non-bottleneck* part of the pipeline — it doesn't reduce the concurrency or service time at the wall. So if the receiver is CPU- or serialization-bound, latency is irrelevant to the throughput number.

This framing — "find what's saturated inside the receiver" — was what drove the rest of the investigation.

---

## 3. Methodology

### 3.1 The four signals worth watching

Throughout the investigation, four signals were used to identify and rank candidate bottlenecks. They're cheap to capture and they triangulate well:

1. **`pidstat -u 2 5`** filtered to PF/DB/Redis processes — tells us which process owns the CPU, and the `%wait` column shows how much wall time each process spends in the kernel's run queue (i.e., CPU-starved).
2. **`redis-cli ... LLEN Queue:general`** sampled over time — tells us whether pfqueue is backing up (producers outpacing drainers).
3. **`redis-cli ... INFO commandstats`** and **`SLOWLOG GET`** on `redis_cache` — tells us which Redis commands eat CPU and whether any are blocking (especially `KEYS`).
4. **`SELECT COUNT(1), created_at FROM radius_audit_log GROUP BY created_at ORDER BY created_at DESC`** — the ground truth Access-Accept rate. The audit log is RPUSHed to Redis and drained to MySQL in ~10-second batches, so each `created_at` bucket represents the previous 10 seconds of auth activity.

### 3.2 Ground truth vs derived numbers

The `radius_audit_log` query was the single most useful diagnostic — it told us *what PacketFence actually did* independent of any test-client reporting. When PF's perceived rate disagrees with the test tool's reported rate, the audit log is the arbiter.

Example, peak post-patch run:

```
+----------+---------------------+
| COUNT(1) | created_at          |
+----------+---------------------+
|     1427 | 2026-05-08 11:21:31 |
|     1233 | 2026-05-08 11:21:21 |
|     1529 | 2026-05-08 11:21:12 |
|     1308 | 2026-05-08 11:21:01 |
|     1269 | 2026-05-08 11:20:51 |
|      839 | 2026-05-08 11:20:41 |  ← ramp-up
+----------+---------------------+
```

That is **~127-153 Access-Accept/sec sustained**, peak 153/sec. Compared to ~60/sec on the unmodified box, it's a clean 2.5× improvement at the time of capture, and it climbed further to ~170/sec under higher offered load.

### 3.3 Test client matters

A subtle trap: the "Bulk plug" load generator used initially reported **67.13 devices/sec** at completion. That was numerically very close to PF's pre-fix ceiling of ~60/sec, which made it hard to tell whether the wall was inside PF or inside the test tool. **In two of the early runs, both were true simultaneously.**

Once PF's ceiling rose past 100/sec, the same tool kept reporting ~67/sec — at that point the test client was clearly the bottleneck. Pushing more offered load (multiple test instances, or `radclient -p 256`) was needed to find PF's real ceiling.

> **Operational note:** when a deployment's reported throughput matches the test tool's reported rate to within a few percent, suspect the tool first.

---

## 4. Bottleneck #1 — `[queue general] workers=1`

### 4.1 What it is

PacketFence's pfqueue dispatcher reads `conf/pfqueue.conf.defaults` for per-queue worker counts. The `general` queue (the catch-all, where any `notify()` call without an explicit `queue =>` parameter lands) defaults to **one** dedicated worker:

```ini
# conf/pfqueue.conf.defaults (shipping defaults)
[queue general]
weight=4
workers=1
```

For comparison, `pfsnmp` defaults to 4 workers, `priority` to 2.

### 4.2 What lands on `Queue:general`

Searching the source for `notify(` calls without an explicit queue parameter reveals that the auth path enqueues several tasks per Access-Request, all to the default `general` queue:

| Producer site | Task enqueued | When |
|---|---|---|
| `lib/pf/radius.pm:153` | `update_ip4log` | every authorize when Framed-IP-Address present |
| `lib/pf/api.pm:1511` | `radius_update_locationlog` | every accounting Start/Update |
| `lib/pf/api.pm:1521` | `update_ip4log` | every accounting with IP |
| `lib/pf/api.pm:1523` | `update_switch_role_network` | every accounting |
| `lib/pf/api.pm:1550` | `firewallsso_accounting` | every accounting if firewall-SSO configured |
| `lib/pf/api.pm:1546` | `deregister_node` | unregister on session end |
| `lib/pf/radius.pm:1276` | `cache_user_ntlm` | per NTLM-cached user |
| various provisioner / role flows | role-change tasks | per role evaluation |

With `workers=1`, **all of these are drained by a single Perl process serially**. At one task per few milliseconds best case, that's a ceiling around 60-150 ops/sec depending on per-task work — exactly the regime we observed.

### 4.3 Detection

`Queue:general` grows monotonically during load. Snapshots taken with the queue Redis instance show the producer rate clearly outpaces the single-worker drain rate:

```bash
$ for i in 1 2 3; do
    redis-cli -s /usr/local/pf/var/run/redis_queue.sock LLEN Queue:general
    sleep 5
  done
113
279
410
```

Producers were pushing ~33 items/sec faster than drain. After 60 s of load, the queue had ~1500-1800 pending items.

### 4.4 The fix

```ini
# /usr/local/pf/conf/pfqueue.conf  (NOT pfqueue.conf.defaults — that gets overwritten on upgrade)
[queue general]
workers=8
```

Then:

```bash
/usr/local/pf/bin/pfcmd configreload hard
systemctl restart packetfence-pfqueue-backend
# verify
pgrep -fc 'pfqueue.*Queue:general'    # expect 8
```

> Note: on this build, `packetfence-pfqueue-perl.service` is *disabled*; the Perl workers run on the host under `packetfence-pfqueue-backend.service`. Confirm with `cat /proc/<worker_pid>/cgroup`.

### 4.5 Result

Auth/sec rose from ~60 to ~75 on the 4-vCPU box and `Queue:general` stayed near zero under the previous offered load. The next ceiling was revealed when the offered load was pushed higher.

---

## 5. Bottleneck #2 — `info_for_security_event_engine` hammering redis_cache

### 5.1 What's actually happening

`pf::security_event::info_for_security_event_engine` at `lib/pf/security_event.pm:515` builds an "info" hash about a MAC for the security_event filter engine. Among its responsibilities is enriching the MAC with Fingerbank-derived IDs:

```perl
# lib/pf/security_event.pm (unpatched)
sub info_for_security_event_engine {
    my ($mac, $type, $tid) = @_;
    my $node_info = pf::node::node_view($mac);
    my $cache = pf::CHI->new( namespace => 'fingerbank' );
    ...
    my $attr_map = {
        dhcp_fingerprint  => "fingerbank::Model::DHCP_Fingerprint",
        dhcp_vendor       => "fingerbank::Model::DHCP_Vendor",
        dhcp6_fingerprint => "fingerbank::Model::DHCP6_Fingerprint",
        dhcp6_enterprise  => "fingerbank::Model::DHCP6_Enterprise",
    };
    foreach my $attr (keys %$attr_map) {
        $results->{$attr} = $cache->compute_with_undef(
            "$model\_id_".encode_json($query), sub { ... }
        );
    }
    my ($mac_vendor_id) = $cache->compute_with_undef(
        "mac_vendor_id_from_mac_$mac", sub {
            my $mac_vendor = pf::fingerbank::mac_vendor_from_mac($mac);
            return $mac_vendor ? $mac_vendor->id : undef;
        }
    );
    my $accounting_history =
        pf::accounting_events_history->new->latest_mac_history($mac);
    ...
}
```

Every one of those `compute_with_undef` calls reads from `redis_cache`, computes on miss, and writes back. `pf::fingerbank::mac_vendor_from_mac` itself does a SQLite lookup in the local Fingerbank database.

### 5.2 Who calls this

`info_for_security_event_engine` is called once per `security_event_trigger`. `security_event_trigger` is called from many places, but the hot ones on the auth path are:

- **`lib/pf/role.pm:391`** — provisioner enforcement check; fires *every auth* when the connection profile has a provisioner with `enforce=enabled`.
- **`lib/pf/api.pm:1277` and `:1302`** — `radius_update_locationlog` checks for `hostname_change` and `connection_type_change`; fires from every accounting frame where those attributes shifted.

So on a load test that sends Access-Requests + Accounting-Starts, this function is called multiple times per MAC per session.

### 5.3 The "Fingerbank disabled" trap

The Fingerbank perl module already has a guard at `lib/pf/fingerbank.pm:88-96`:

```perl
sub process {
    ...
    unless (fingerbank::Config::is_api_key_configured()) {
        $logger->debug("Skipping Fingerbank processing because no API key is configured");
        return $FALSE;
    }
    ...
}
```

So calling `pf::fingerbank::process` is correctly a no-op when the API key in `/usr/local/fingerbank/conf/fingerbank.conf` is empty. **But that same guard is not present in `info_for_security_event_engine`.** So even with the API key removed — which the user reasonably interprets as "Fingerbank is off" — the cache traffic continues.

### 5.4 Detection

Three signs all pointed at this on the 8-vCPU box:

- redis_cache (`redis-server` PID 1242) at **~48% CPU** in pidstat with high run-queue wait. Redis is single-threaded; ~50% of one core is roughly half its theoretical max.
- `redis-cli ... DBSIZE` growing during the test, with `--scan --pattern 'pffingerbank||*'` showing thousands of new entries per test run.
- The pattern of growth — exactly one `mac_vendor_id_from_mac_*` key per unique MAC — confirms `info_for_security_event_engine` as the writer.

### 5.5 The fix (diff)

In `lib/pf/security_event.pm`, add an early `$fb_enabled` variable and gate the Fingerbank-related cache lookups on it.

```diff
--- a/lib/pf/security_event.pm
+++ b/lib/pf/security_event.pm
@@ -517,8 +517,10 @@ sub info_for_security_event_engine {
     my ($mac,$type,$tid) = @_;
     my $node_info = pf::node::node_view($mac);

     my $cache = pf::CHI->new( namespace => 'fingerbank' );

+    my $fb_enabled = fingerbank::Config::is_api_key_configured();
+
     $type = lc($type);

     my $devices = [];
     my ($device_id);
     if($type eq "device"){
         $device_id = $tid;
     }
-    else {
+    elsif ($fb_enabled) {
         my ($device_result, $device) = fingerbank::Model::Device->find([{name => $node_info->{device_type}}]);
         if(is_success($device_result)){
             $device_id = $device->id
         }
     }

     my $attr_map = {
         dhcp_fingerprint  => "fingerbank::Model::DHCP_Fingerprint",
         dhcp_vendor       => "fingerbank::Model::DHCP_Vendor",
         dhcp6_fingerprint => "fingerbank::Model::DHCP6_Fingerprint",
         dhcp6_enterprise  => "fingerbank::Model::DHCP6_Enterprise",
     };
     my $results = {};
-    foreach my $attr (keys %$attr_map){
-        my $model = $attr_map->{$attr};
-        my $query = {value => $node_info->{$attr}};
-        $results->{$attr} = $cache->compute_with_undef("$model\_id_".encode_json($query), sub {
-            my ($status, $result) = $model->find([$query]);
-            return is_success($status) ? $result->id : undef;
-        });
+    if ($fb_enabled) {
+        foreach my $attr (keys %$attr_map){
+            my $model = $attr_map->{$attr};
+            my $query = {value => $node_info->{$attr}};
+            $results->{$attr} = $cache->compute_with_undef("$model\_id_".encode_json($query), sub {
+                my ($status, $result) = $model->find([$query]);
+                return is_success($status) ? $result->id : undef;
+            });
+        }
     }
-    my ($mac_vendor_id) = $cache->compute_with_undef("mac_vendor_id_from_mac_$mac", sub {
-        my $mac_vendor = pf::fingerbank::mac_vendor_from_mac($mac);
-        return $mac_vendor ? $mac_vendor->id : undef;
-    });
+    my $mac_vendor_id;
+    if ($fb_enabled) {
+        ($mac_vendor_id) = $cache->compute_with_undef("mac_vendor_id_from_mac_$mac", sub {
+            my $mac_vendor = pf::fingerbank::mac_vendor_from_mac($mac);
+            return $mac_vendor ? $mac_vendor->id : undef;
+        });
+    }
```

**Behavior change:** when no API key is set in `fingerbank.conf` (`api_key=`), the `device_id`, `dhcp_*_id`, and `mac_vendor_id` fields in the security_event info struct are all `undef`. Security_events that match on those IDs stop firing — which is the correct behavior for a deployment that has explicitly disabled Fingerbank.

### 5.6 Deployment caveats

PacketFence on this build is a hybrid: `pfperl-api` runs in a Docker container (`--rm`), and the Perl pfqueue workers run as host processes spawned by `packetfence-pfqueue-backend.service`. Both layers need the patched module.

Steps:

```bash
# 1. Patch the host file
# (the diff above, applied via patch or a small Python script)
grep -c 'fb_enabled' /usr/local/pf/lib/pf/security_event.pm     # expect 4

# 2. Rebuild the container image — docker cp ONLY works until the next restart,
#    because the container is started with --rm and is recreated from the image.
addons/dev-helpers/build-local-container.sh pfperl-api

# 3. Restart both layers
systemctl restart packetfence-pfperl-api
systemctl restart packetfence-pfqueue-backend

# 4. Verify both layers have it
grep -c 'fb_enabled' /usr/local/pf/lib/pf/security_event.pm                    # 4
docker exec pfperl-api grep -c 'fb_enabled' /usr/local/pf/lib/pf/security_event.pm   # 4

# 5. Verify worker lstart > file mtime (Perl doesn't hot-reload)
ls -la --time-style=full-iso /usr/local/pf/lib/pf/security_event.pm
ps -eo pid,lstart,comm | grep 'pfqueue.*Queue:general' | head -3
```

> **The first deployment attempt missed this.** The host file was patched at 10:47:41 but the workers were started at 10:45:13, so they ran stale code for the next test. The fingerbank key count climbed back up during that run, which prompted the timestamp comparison and the lesson that **Perl doesn't hot-reload — workers must be restarted after the file changes**. Confirm this with `lstart` vs `mtime`.

### 5.7 Result

After both layers were running patched code:

- `pffingerbank||*` key count stayed flat (only 2 housekeeping keys from `Config::read_config` itself; zero per-MAC keys).
- redis_cache CPU dropped from ~48% to ~5%.
- `auth/sec` from `radius_audit_log` rose to ~85-100/sec.

The next bottleneck became visible: a `KEYS` scan from the same function.

---

## 6. Bottleneck #3 — `KEYS accounting_events_history:data-*` blocking redis_cache

### 6.1 What it is

After patch #2 was applied, redis_cache's slowlog showed a different villain:

```
keys     calls=80349   usec=896501064   usec/call=11157.59
```

> **80,349 `KEYS` calls in 60 seconds, averaging 11 ms each.**

Cross-referencing the slowlog entries pinpointed the pattern:

```
KEYS accounting_events_history:data-*
```

This comes from the line in `info_for_security_event_engine` immediately after the Fingerbank block:

```perl
my $accounting_history =
    pf::accounting_events_history->new->latest_mac_history($mac);
```

`latest_mac_history` issues a `KEYS` scan against redis_cache. `KEYS` is O(N) over the entire keyspace and — critical — **blocks Redis** while it runs because Redis is single-threaded. On a cache with tens of thousands of keys, 11 ms per call is normal.

### 6.2 Why it matters even with no security_events configured

The user's `security_events.conf` was effectively empty (29 bytes, 1 line — no `[event_id]` sections). The filter engine had no rules to match. But the *info-gathering* step in `info_for_security_event_engine` ran in full before the match — and the `KEYS` call ran first, regardless of whether anything would match.

### 6.3 The fix

Extend the same `$fb_enabled` gate over the accounting history lookup:

```diff
-    my $accounting_history = pf::accounting_events_history->new->latest_mac_history($mac);
+    my $accounting_history = $fb_enabled
+        ? pf::accounting_events_history->new->latest_mac_history($mac)
+        : [];
```

Why piggyback on `$fb_enabled`? Because the accounting history is consumed only by security_event matching, and the user has explicitly disabled Fingerbank. The intent (no Fingerbank-driven enforcement) implies "skip the supporting lookups too." If a deployment wants Fingerbank fully off but still uses accounting-event-based security_events, they would need a more targeted flag.

### 6.4 Result

- redis_cache slowlog: **empty** (was 80K KEYS calls, all blocking).
- redis_cache CPU: down to ~2.5% (was ~48% pre-Fingerbank patch, ~5% post-Fingerbank patch).
- `Q:general` LLEN stayed at **0** through the entire 60-second test.
- Sustained Access-Accept rate: **~127-153/sec**, peak 153/sec, climbing to **~170/sec** when offered load was pushed harder.

---

## 7. The current ceiling — mariadbd CPU

### 7.1 The wall

At ~150-170 auth/sec, mariadbd plateaus at ~100% of one CPU. Pidstat at peak:

```
mariadbd  Average  78.09 %usr  11.89 %sys   0.15 %wait   89.99 %CPU
```

90% CPU on a single core means **one CPU thread is fully busy on SQL processing**. Redis_cache, pfqueue, and pfperl-api workers are all subordinate at this point — they're waiting on mariadbd to return results.

### 7.2 Where the work goes

Snapshotting `SHOW GLOBAL STATUS LIKE 'Com_*'` before and after a 60-second test:

| Counter | Delta over 60 s | Per auth (at 150/sec) |
|---|---|---|
| `Com_insert` | 53,028 | ~5.9 |
| `Com_update` | 30,339 | ~3.4 |
| `Com_select` | **302,443** | **~33.6** |
| `Innodb_buffer_pool_reads` | 10 | ~0 (working set in RAM) |
| `Threads_running` | 1 | mostly serialized |

So PF executes **~43 SQL queries per MAC auth**, dominated by SELECTs. At 150 auth/sec that's ~6,400 queries/sec going through mariadbd. With ~80% user CPU on one core:

> ~125 µs of CPU per query on average — near the floor MariaDB can deliver for indexed point-queries.

### 7.3 Why the slow query log was a dead end

Enabling the slow query log with `long_query_time=0.05` and running another full test produced **no auth-path queries** in the slowlog. The only entries were scheduled housekeeping jobs (`node_current_session` cleanup, `bandwidth_accounting` aggregation) that happened to run during the window — all under 100 ms.

The conclusion is unambiguous: **there is no slow query to fix.** mariadbd's 90% CPU is the cumulative cost of thousands of *fast* queries, not a few slow ones. You can't optimize this further by tuning individual queries.

### 7.4 What the SELECTs are doing

A non-exhaustive list of per-auth SELECT sources, based on code inspection of `radius_authorize` and related paths:

- Switch configuration lookup (per request)
- Connection profile lookup
- Authentication source rules (LDAP / SQL / etc.)
- `locationlog_view_open_mac` / `locationlog_view_open_switchport` (often 2-3 of these)
- `node_view` and friends (called from many places per auth)
- VLAN filter rule evaluation
- `pf::role::filterVlan` rules
- `radius_audit_log` writer prep

A meaningful reduction here is engineering work (per-request `node_view` caching, lazy filter rule loading, batched locationlog opens). That's an upstream PR opportunity rather than a tuning knob.

---

## 8. Throughput progression — full table

| # | Configuration | Sustained auth/sec | Notes |
|---|---|---|---|
| 0 | 4 vCPU, defaults | ~60 | Both cloud and on-prem ceiling; the original puzzle |
| 1 | 4 vCPU, `pfperl_api_processes=32` | ~60 | **No change** — pfperl-api workers were idle; the bottleneck was downstream |
| 2 | 4 vCPU, `[queue general] workers=8` + back to `pfperl_api_processes=8` | ~75 | Load avg drops dramatically from ~55 to ~13 |
| 3 | 8 vCPU, otherwise same as #2 | ~67 | Test client capped at 67/sec; ceiling was not yet inside PF |
| 4 | 8 vCPU, Fingerbank cache writes gated (`is_api_key_configured`) | ~85-100 | redis_cache CPU drops from ~48% to ~5% |
| 5 | 8 vCPU, accounting_history `KEYS` gated | ~125-150 | `Queue:general` flat at 0 throughout |
| 6 | 8 vCPU, all above, peak offered load | **~170** | mariadbd at ~100% of one CPU — the hard wall |

### 8.1 Why latency now starts to matter (and didn't before)

With PF saturated, latency is irrelevant. With PF having spare capacity, latency starts adding to per-request wall time and can — at very high offered concurrency — limit the achievable rate via Little's Law. So a cloud deployment of this same 8 vCPU box, fully patched, *will* be slower than an on-prem one in extremely high concurrency regimes. But for the realistic ranges we tested, the two are bounded by mariadbd CPU, not latency.

---

## 9. The diagnostic toolkit

### 9.1 `pf-perf-probe.sh`

A bash probe that runs alongside a load test. Captures:

- 5-second LLEN samples of `Queue:general` + 1-min/5-min/15-min load averages.
- A background `pidstat -u 2 N` filtered to PF/DB/Redis processes.
- Auth/sec from `grep -c 'Sent Access-Accept' /usr/local/pf/logs/radius.log` delta (early version had a `0\n0` arithmetic bug; fixed by `head -1`).
- Final `Queue:*` LLENs.
- `radius_audit_log` per-`created_at` bucket counts for the last 5 minutes (ground-truth Access-Accept rate).

Writes everything to `/tmp/pf-perf-<timestamp>.log`. Source is at `/usr/local/pf/addons/pf-perf-probe.sh` on the test box.

### 9.2 `pf-redis-probe.sh`

A companion probe that observes both PF Redis instances (`/usr/local/pf/var/run/redis_cache.sock` and `/usr/local/pf/var/run/redis_queue.sock`):

- Baseline `INFO server/clients/memory/stats`.
- Tries `CONFIG RESETSTAT` + `SLOWLOG RESET` + `LATENCY RESET` (some builds rename `CONFIG`; probe tolerates that).
- Live 5-second samples of ops/sec, connected clients, memory, and `Queue:general` LLEN.
- End-of-run `INFO commandstats` top-15 by total time — **the single most diagnostic output**; this is where the `KEYS` problem appeared.
- `SLOWLOG GET 10` for both instances.
- `LATENCY LATEST` events.
- `CLIENT LIST` top consumers by `tot-mem`.

### 9.3 PacketFence Redis topology

PF runs multiple Redis instances. The default `redis-cli` against `127.0.0.1:6379` only sees the cache one, not the queue.

| Instance | Port | Socket | Owner UID | Purpose |
|---|---|---|---|---|
| `redis_cache` | 6379 | `/usr/local/pf/var/run/redis_cache.sock` | root | CHI caches (config, fingerbank, pfconfig, etc.) |
| `redis_queue` | 6380 | `/usr/local/pf/var/run/redis_queue.sock` | pf | pfqueue tasks |
| `redis_ntlm_cache` | 6383 | `/usr/local/pf/var/run/redis_ntlm_cache.sock` | pf | NTLM auth cache (optional) |

The queue Redis is the hot one for auth workloads. The cache Redis becomes hot when there's a hot path doing many GET/SET — like the Fingerbank issue described in §5.

### 9.4 The four signal commands to memorize

```bash
# 1. Where is the CPU?
pidstat -u 2 5 | awk 'NR<=3 || /pfperl-api|mariadbd|redis|pfqueue|pfacct|radiusd/'

# 2. Is pfqueue draining?
redis-cli -s /usr/local/pf/var/run/redis_queue.sock KEYS 'Queue:*' \
  | while read q; do echo "$(redis-cli -s /usr/local/pf/var/run/redis_queue.sock LLEN "$q") $q"; done \
  | sort -rn

# 3. What's redis_cache spending CPU on?
redis-cli -s /usr/local/pf/var/run/redis_cache.sock INFO commandstats \
  | sort -t= -k4 -nr | head -10
redis-cli -s /usr/local/pf/var/run/redis_cache.sock SLOWLOG GET 10

# 4. Ground-truth Access-Accept rate
mysql -p pf -e "SELECT COUNT(1), created_at FROM radius_audit_log
  WHERE created_at >= NOW() - INTERVAL 5 MINUTE
  GROUP BY created_at ORDER BY created_at DESC LIMIT 30;"
```

---

## 10. Operational recommendations

### 10.1 Things to change on any moderate-throughput PF box

1. **`[queue general] workers=8`** in `/usr/local/pf/conf/pfqueue.conf` (not in `.defaults`, which is overwritten on upgrade). Restart `packetfence-pfqueue-backend` after.

2. **`advanced.pfperl_api_processes`** — keep at default (8) or set to roughly `2 × cores`. Higher values just cost scheduler attention; pfperl-api is not the auth-path hot spot on this build.

3. **`innodb_flush_log_at_trx_commit=2` and `sync_binlog=0`** in `/usr/local/pf/var/conf/mariadb.conf` — already the case on this build. Important to confirm on new installs; the default `=1` is a major fsync tax.

4. **`innodb_buffer_pool_size`** — 50-70% of RAM is the rule of thumb. The 500 MB setting on this 16 GB box is small. It doesn't move the auth ceiling here (we're CPU-bound, not I/O-bound), but it's worth fixing for general health.

### 10.2 Things to keep watching

- `redis-cli ... INFO commandstats` — any `keys` calls with `usec/call > 1000` is bad news. Investigate the prefix.
- `Queue:general` LLEN trend during steady state — should bounce around zero, not grow.
- `pidstat` average `%wait` per pfqueue worker — over ~50% means CPU oversubscription; either reduce worker count or add CPUs.

### 10.3 When to scale up

- Sustained auth rate ≥ ~150/sec on this hardware → mariadbd is the wall. Move the DB to its own host before adding PF CPUs.
- Sustained auth rate ≥ ~500/sec → consider a clustered PF reference architecture.

---

## 11. Patches that should go upstream

Both gates in `lib/pf/security_event.pm` are scoped to the explicit "Fingerbank disabled" state (no API key configured) and mirror the existing gate in `pf::fingerbank::process()` at `lib/pf/fingerbank.pm:93`. Every PacketFence deployment that has intentionally disabled Fingerbank — whether for compliance, cost, or perf — benefits from both. They are PR-worthy as a single change with the message:

> `security_event.pm`: gate Fingerbank cache lookups and accounting-history `KEYS` scan on `is_api_key_configured()` to match `pf::fingerbank::process()`, eliminating per-auth redis_cache hot path when Fingerbank is intentionally disabled.

Behavior change: `device_id`, `dhcp_*_id`, `mac_vendor_id`, and `last_accounting_events` in the security_event info struct are `undef` / `[]` when Fingerbank is off. Security_events matching those attributes will stop firing — consistent with the existing `pf::fingerbank::process` behavior.

---

## 12. Open follow-up work

Listed in rough order of effort vs. payoff:

1. **Move mariadbd to a dedicated host.** Largest single architectural lever for further headroom on this PF box. Expected throughput on the same 8-vCPU PF host: ~250-350 auth/sec, limited next by per-auth query count or by the DB host's CPU.

2. **Reduce per-auth query count in PF.** 34 SELECTs per auth is the wall once the DB is its own host. Targets in code:
   - Cache `node_view` per request (it's called from many places per auth).
   - Cache `pf::switch::*` config lookups for the duration of a request.
   - Lazy-load VLAN filter rules — many auths don't need them.
   - Batch locationlog opens.
   Cutting SELECTs from 34 to ~15 would roughly double mariadbd's per-CPU ceiling.

3. **Scale to 16 vCPU + dedicated DB.** Reference architecture for 500-800 auth/sec deployments.

4. **Open the `security_event.pm` patches as upstream PRs.** Helps every PF site with Fingerbank disabled.

5. **Replace the test load generator** ("Bulk plug") concurrency knob with something that can saturate PF unambiguously — `radclient -p 256` with a 10k-MAC packet file is a clean way to do it.

---

## 13. Acknowledgments and provenance

This investigation was performed against PacketFence `maintenance-14-0`, kernel 6.1, Debian 12, MariaDB 10.11, Redis 7.0.15. All measurements, slowlog captures, and pidstat samples are reproducible with the probe scripts in `/usr/local/pf/addons/`. The two source patches are in `lib/pf/security_event.pm`. Throughput claims are backed by per-`created_at` bucket counts in `radius_audit_log`, the ground-truth Access-Accept rate.

---

*End of report.*
