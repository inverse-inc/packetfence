# pf-cluster-upgrade

Automates **"Performing an upgrade on a cluster"** from the PacketFence
Clustering Guide, section 12.4, for a 3-node cluster. The version upgrade of
each node itself runs as in Upgrade Guide 5.1, with `do-upgrade.sh` — exactly as
12.4.4 prescribes ("apply the upgrade process described here on node C only").

The script is started on **one** node and drives all three over SSH.

## Roles

`A`, `B` and `C` follow the **order in `cluster.conf`** — the way the guide
defines them. `C` is the node that is detached from the cluster first, upgraded,
and then put into service on its own. `--pioneer HOST` picks a different node
as `C`.

The assignment is recorded in `/root/.pf-cluster-upgrade.state` on the first
run. If it differs later, the script aborts — otherwise a following phase would
touch the wrong nodes. After `finish` the file is deleted so that the next
upgrade starts clean; `--keep-state` keeps it.

---

## The procedure

| Phase | Guide | What happens |
|---|---|---|
| `preflight` | — | Minimal checks, read-only |
| `prepare` | 12.4.2, 12.4.3 | Switch off cluster check and galera-autofix |
| `upgrade-c` | 12.4.4 | Detach C, `do-upgrade.sh`, `checkup`, stop A+B, start C |
| *(review pause)* | 12.4.5 | Functional check by you |
| `upgrade-ab` | 12.4.5 | Upgrade A and B, pull the configuration from C |
| `reintegrate` | 12.4.6, 12.4.7 | Enable members, C as master, resync A+B |
| `finish` | 12.4.8, 12.4.9 | Put cluster check and galera-autofix back |
| `rollback` | 12.4.5 | "If all goes wrong" — back to A and B |

```bash
sudo ./pf-cluster-upgrade.sh run --target-version 15.2
```

That is the normal case: one call, from `preflight` to `finish`. It stops
**exactly twice** — before `upgrade-c` for the VM snapshots and after it for the
functional check of 12.4.5. An error ends the run at once, names the phase that
failed and the command to continue with:

```bash
sudo ./pf-cluster-upgrade.sh run --resume --target-version 15.2
```

Running the phases one by one is still possible:

```bash
./pf-cluster-upgrade.sh preflight
./pf-cluster-upgrade.sh prepare
./pf-cluster-upgrade.sh upgrade-c --target-version 15.2
./pf-cluster-upgrade.sh upgrade-ab --target-version 15.2
./pf-cluster-upgrade.sh reintegrate
./pf-cluster-upgrade.sh finish
```

Every phase ends with the command for the next one.

---

## What preflight checks

Deliberately short — only what really blocks the procedure:

1. root and PacketFence present
2. Every node has an address: `management_ip` from `cluster.conf`, otherwise a
   resolvable name
3. SSH as root to all three nodes (without all three the procedure cannot be driven)
4. The same PacketFence version on every node
5. `do-upgrade.sh` and `bin/cluster/node` present
6. Free space in `/var/lib/mysql`, under `/root` and in the apt cache
7. No package in a broken state (`iF`, `iU`, pending triggers)
8. No locally modified package files that the upgrade would silently overwrite
9. All services running — and whatever is already down is recorded as the
   baseline
10. Galera `Primary` / `Synced` / `cluster_size=3` on every node
11. The repository of the target version is reachable (a warning only)
12. The target version is not the one already running (a warning with a
    question — see below)

Plus a note when the nodes carry different PacketFence **package** builds:
`pfcmd version` only reports `15.1.0` and hides differing maintenance builds.

No certificate or time check — that is not part of 12.4.

### Upgrading to the version already running

Nothing stops you, and for a maintenance build inside the same minor
(15.2.0 → 15.2.1) that is exactly right. But the procedure runs in full either
way — an outage and a complete resync for A and B, whether the package changes
or not. Preflight says so and `upgrade-c` asks once.

Since `15.2 == 15.2` would hold no matter what happened, the check afterwards
compares the **full package version** before and after `do-upgrade.sh`:
unchanged means nothing was installed, and that is reported instead of a green
tick.

### How the members are found

From the section names in `/usr/local/pf/conf/cluster.conf`, in the order they
appear there. Sections with a space in the name (`[node interface eth0]`) and
`[CLUSTER]` are skipped.

The section name is a node's **identity** — only under it does
`bin/cluster/node` find it. Its **address** is the `management_ip` from the same
file, which keeps the procedure independent of DNS and `/etc/hosts`. Without a
`management_ip` the name is tried as an address; without either, preflight
aborts. `NODES=(<IP> …)` is **no** substitute: `bin/cluster/node` looks nodes up
by hostname and rejects an IP.

### What "healthy" means

`pfcmd service pf status` gives one line per unit: the unit name, a tab, and one
of `started` / `stopped` / `disabled` / `reloading`. `disabled` means: not
managed by PacketFence at all — not an error.

On a running cluster some service is almost always down on purpose. So preflight
records per node what is **already** down; from then on only a deterioration
against that baseline counts.

An **empty** baseline — "everything runs" — is recorded as such and kept. Take
the baseline while a node happens to be booting, though, and its outage counts
as normal for the rest of the procedure.

After the version switch the set of services changes legitimately. That is what
`--rebaseline` is for:

```bash
sudo ./pf-cluster-upgrade.sh preflight --rebaseline   # before the start
sudo ./pf-cluster-upgrade.sh status --rebaseline      # while it is running
```

The second form is the important one: once the procedure is under way preflight
refuses to work (it insists on the initial state), and `status` keeps the
baseline correctable anyway.

---

## The switch-over window

12.4.4 has a moment in which no node carries traffic: A and B are stopped, and
C takes over on its own. Part of that is unavoidable, part of it was homemade —
without the measures below, all three nodes can be down at once while C already
holds the VIP but cannot yet serve it, because `radiusd` and `haproxy-portal`
are still starting.

**What cannot go away.** C must not carry services or database before A and B
are provably stopped — otherwise two halves accept writes. The stop therefore
stays where it is, and so does the window it opens.

**What the script does about the rest.**

*The configuration work runs before the window.* `pfconfig clear_backend`,
`configreload hard` and the `CONFIG_SETTLE_SECS` pause need nothing from the
other nodes, so they are their own step (`RS_PREP_CONFIG`) ahead of the stop.
Only `pfcmd service pf restart` is left inside the window.

*keepalived starts last.* `service pf restart` releases 30+ units at once,
keepalived among them — the VIP could arrive before the node can serve it. It is
**masked** before the start (masked, not stopped: the isolate would bring it
straight back), released once the other services are healthy, and started
explicitly. While held back it does not count as an outage (`SERVICES_IGNORE`).
A masked keepalived means a cluster without a VIP, so it is released on every
path, including the `EXIT` trap.

*The handover is proved, not assumed.* `wait_vip` waits until the address is
really on the node's interface; a keepalived reporting `started` says nothing
about VRRP. The VIP is the `management_ip` of `[CLUSTER]` — read for this check
only, and **never** as an ssh target, because it moves.

*The window is timed.* `outage window: <N>s` goes into the log. Most of it is
the serial stop of A and B and the start of C.

*Nothing waits twice.* C's health is established once, inside the staged start.
The second wait runs only on the `--resume` path, where the start was skipped
and the node's health is therefore unknown.

*Units stuck outside the target are cleared.* `packetfence-tracking-config`
lands in `start-limit-hit` after every configuration storm; it is not in the
target's `Wants`, so `revive_failed_units` never sees it, and left failed it
makes systemd report `degraded`. After each staged start — and once more in
`finish` — such units have their failed state cleared and their `.path` triggers
re-armed. Services outside the `Wants` list are deliberately not started:
PacketFence does not manage them.

`reintegrate` starts its nodes the same way: A and B coming back must not pull
the VIP off C while they are still starting, and 12.4.7 restarts C itself.

## Why there is no `apt upgrade`

`run-upgrade.sh` already does `apt update` + `apt upgrade` in
`apt_upgrade_packetfence_package()`, and with `INCLUDE_OS_UPDATE=yes` the
operating system as well. This script therefore deals only with **preparation
and follow-up** per Clustering Guide 12.4; the package part belongs to
`do-upgrade.sh`. Touching package management past the order PacketFence expects
is where the pitfalls live.

### No reboot

**The script never reboots a node.** 12.4 does not provide for one — after
`do-upgrade.sh` the section goes straight to
`systemctl start packetfence-proxysql` and `checkup`. `run-upgrade.sh` itself
only ends with a note to reboot if the kernel changed.

## Cluster check and galera-autofix

The guide describes both through the web interface. Behind them are two ordinary
configuration files, and those are what the script writes directly:

| Web UI | File |
|---|---|
| Maintenance → task `Cluster Check` | `conf/pfcron.conf` → `[cluster_check] status=` |
| Services → `galera-autofix` | `conf/pf.conf` → `[services] galera-autofix=` |

`prepare` switches both off, `finish` switches them back on — per node, each
followed by the CLI parts (`pfcron restart`, `galera-autofix
updatesystemd/stop`). Both phases read the file back afterwards; if writing
fails, the error names the way through the web interface.

## Three things only a real run shows

Fixed, but easy to undo by accident:

- **`/run` is often mounted `noexec`.** The detached script lives there and is
  therefore *read* (`bash '/run/<unit>.sh'`), not executed — a direct call ends
  with code 126.
- **`packetfence.preinst` runs `systemctl isolate packetfence-base.target`**,
  which would stop the transient unit `do-upgrade.sh` runs in, mid-transaction.
  Hence `systemd-run --property=IgnoreOnIsolate=yes`.
- **galera-autofix must be masked, not just stopped.** That same isolate starts
  it right back up; the postinst then takes `packetfence-config` away from it,
  and without pfconfig it declares the node broken and shuts its `mariadbd`
  down.

## Fail-safe

- `set -Eeuo pipefail` plus an ERR trap: any unexpected error aborts with a line
  number and the command.
- Every error message names the next step and, where it makes sense, the way back.
- **`--resume`** skips steps already done. After an abort in the middle of a
  phase it continues at the point of the abort instead of repeating detach steps
  that already succeeded.
- **`--dry-run`** shows every changing action without carrying it out, and
  writes no state.
- **Dropped connections cost no progress** — see the section of its own below.
- All prompts are English and are answered yes with `yes` (or `y`); anything
  else counts as no. With the `confirm` prompts a different answer ends the run,
  an empty line asks again (three times, then it gives up).
- `rollback` requires a typed `ROLLBACK` before the data created on C is
  discarded (`--yes` skips that too — when in doubt, leave it out). It then
  discards the step markers of `upgrade-c` **and** `upgrade-ab`, so a retry
  starts from the top; otherwise a later `--resume` would skip stopping A and B
  and start C alongside them.
- Before A and B are started, the stop of C must be **proven**. A stop that only
  reported an error is not enough: two halves would each accept writes.
- `MARIADB_ARGS=--force-new-cluster` (12.4.6) changes the environment of the
  systemd manager and survives every unit restart until it is unset. The script
  therefore clears it wherever the procedure can come to rest, not only on the
  success path — otherwise the next start of MariaDB on C would bootstrap a
  second cluster with a new UUID next to the existing one.
- In `reintegrate` the resync of the second node only happens once the first is
  back in the cluster. If the first does not come back, the second keeps its
  data — it is then the only intact copy besides C.
- The wipe of `/var/lib/mysql` on A and B in `reintegrate` no longer asks: it is
  the prescribed way of 12.4.6 and was confirmed at the start and at the review
  pause. The step is announced before it runs.
- The optional truncation of the history tables (12.4.6) is **not implemented**:
  it throws away RADIUS audit and IP/location history and wants the MariaDB root
  password mid-run. Whoever wants it does it by hand, beforehand.
- Between nodes the script waits for healthy services and for `Synced` before it
  carries on.
- A full log per run under `/usr/local/pf/logs/pfclu-<phase>-<timestamp>.log`.
  Detached runs write to `pfclu-doupgrade.log` on the node in question and are
  filed under a timestamp at the end.
- The webservices password for `cluster/sync` travels inside the script text,
  which reaches the node over stdin — not as an argument, where it would show up
  in the process list on both machines. In the log it is masked by plain string
  replacement, so regex metacharacters in it cannot break the masking.
- The configuration file is **parsed, never sourced**: keys are matched against
  a known list and values taken literally, so a file distributed by git cannot
  run code as root.

## When the connection drops

The script drives everything over SSH. Three cases, three answers:

**The connection hangs half-open.** SSH runs with `ServerAliveInterval=15` /
`ServerAliveCountMax=4`: after about a minute without an answer the connection
fails with an error instead of hanging indefinitely. `ConnectTimeout` alone does
not cover this — it only applies while the connection is being established.

**A brief hiccup during a status query.** Read-only and idempotent calls are
retried up to `RETRY_COUNT` times (only on genuine connection failures, SSH exit
code 255 — a remote command that failed is never retried). The wait loops for
services and Galera keep polling anyway.

**An abort in the middle of `apt upgrade` or `do-upgrade.sh`.** That is the case
that hurts: run directly in the SSH session, the operation would get SIGHUP and
die mid-transaction. Both therefore run **as a transient systemd unit** on the
node (`systemd-run --unit=pfclu-doupgrade --collect`), no longer hanging off the
terminal. The script follows along with short, repeated queries, fetching only
new log lines. If the connection drops, **the operation keeps running on the
node** and the script reattaches.

If the script itself dies (your terminal, your laptop, your VPN), start it
again:

```bash
./pf-cluster-upgrade.sh upgrade-c --resume
```

It notices that the unit is still running or has already finished, does **not**
start it a second time, and simply keeps following. After `DETACH_TIMEOUT` only
the observation ends, not the operation — the script then says how to attach
directly:

```bash
ssh root@NODE 'systemctl status pfclu-doupgrade; tail -f /usr/local/pf/logs/pfclu-doupgrade.log'
```

Short changing commands (`cluster/node ... disable`, `systemctl restart ...`)
still run directly: they take seconds, and all of them are idempotent — after an
abort another pass with `--resume` does no harm.

### The prompts of `do-upgrade.sh`

`do-upgrade.sh` is only a wrapper; the work is done by
`addons/full-upgrade/run-upgrade.sh`. Five places there want input — detached,
the run would have no terminal for them. So they are defused beforehand:

| Place in `run-upgrade.sh` | When it asks | What the script does |
|---|---|---|
| `set_upgrade_to()` | when `UPGRADE_TO` is empty | sets `UPGRADE_TO` from `--target-version` |
| `INCLUDE_OS_UPDATE` | when the variable is empty | sets it (default `no`) |
| `upgrade_database()` | when `mysql -e 'select 1'` fails without credentials | checks that in advance; if needed the password is asked for once and supplied through a `0600` file |
| `handle_devel_upgrade()` | only with devel packages (`db/upgrade-X.X-X.Y.sql` present) | detects it and warns |
| `handle_pkgnew_file()` | when the patch dry-run of a `.dpkg-dist` file fails (`Press enter to continue`) | always feeds `do-upgrade.sh` from a stdin file of blank lines |

The fifth is the nastiest. `run-upgrade.sh` runs with `set -o errexit`; a `read`
without a terminal returns EOF and exit code 1, and the run aborts **halfway
through** — after the package switch and the database migration, but before
`fixpermissions`, `configreload hard` and `service pf updatesystemd`. Any
locally adjusted configuration file triggers it. Hence the stdin file, and hence
`conf/pf-release` being checked afterwards instead of trusting the return code.

Only node C can ask for the database password: `UPGRADE_CLUSTER_SECONDARY=yes`
skips that step on A and B entirely.

For the unknown cases `--interactive-upgrade` runs `do-upgrade.sh` on the
terminal instead, where a prompt can be answered — with the drawback that the
connection then has to hold.

**Why `INCLUDE_OS_UPDATE=no` is the right default:** `run-upgrade.sh` rewrites
the package source to the new version (`sources.list.d/packetfence.list`) and
*then* the OS update would follow. Whether you want that is decided by
`--os-update`; the default is `no`.

## Options

| Option | Effect |
|---|---|
| `--pioneer HOST` | set node C (default: last one in `cluster.conf`) |
| `--nodes a,b,c` | node list and order by hand |
| `--config FILE` | a different configuration file |
| `--target-version X.Y.Z` | required for `upgrade-c`/`upgrade-ab`; passed on as `UPGRADE_TO` |
| `--os-update` | `INCLUDE_OS_UPDATE=yes` for `do-upgrade.sh` (default: `no`) |
| `--interactive-upgrade` | `do-upgrade.sh` on the terminal instead of detached |
| `--dry-run` | change nothing |
| `--resume` | skip steps already done |
| `--rebaseline` | record the service baseline again |
| `--keep-state` | keep the state file after `finish` (deleted otherwise) |
| `--yes` | no questions (not even the typed confirmations) |
| `--no-color` | without colors |

Everything settable in the configuration file is documented in
`pf-cluster-upgrade.conf.example`.

The command line beats the file. The file is read only **after** the arguments —
it is named by `--config`, after all — so command-line values are reapplied
afterwards: `--target-version 15.3` wins against a `TARGET_VERSION=15.2` in the
file, and where the command line is silent the file still applies.

A missing option value is an operating error like any other: exit code 2 plus
the help text.

---

## Installation

Every file sits with its own kind: the scripts next to `do-upgrade.sh`, the
configuration with the other PacketFence configuration files, the documentation
with the rest of the documentation.

| File | |
|---|---|
| `addons/upgrade/pf-cluster-upgrade.sh` | the script, `pf:pf 755` |
| `t/pf-cluster-upgrade/` | the test suite |
| `conf/pf-cluster-upgrade.conf.example` | commented example configuration, `644` |
| `conf/pf-cluster-upgrade.conf` | your own configuration, `600` |
| `docs/pf-cluster-upgrade.README.md` | this file |
| `logs/pfclu-*.log` | the logs |

A configuration of your own is needed as soon as the SSH key has to be entered —
the script looks for none. Everything else it reads from `cluster.conf`:

```bash
cd /usr/local/pf/conf
cp pf-cluster-upgrade.conf.example pf-cluster-upgrade.conf && chmod 600 pf-cluster-upgrade.conf
```

`chmod 600`, because the webservices password may end up in there.

**Why these places:** on a package change `dpkg` only removes its own files, so
ours stay put. `pfcmd fixpermissions` descends into neither `addons/` nor
`conf/` — it only touches the directories themselves and the `@stored_config_files`
it knows by name, so our `600` survives. `upgrade_configuration()` runs only
`to-<version>-*` out of `addons/upgrade/`, and our file names do not match that
pattern. And `bin/cluster/sync` transfers only the files from `@FILES_TO_SYNC`
and `conf/cluster-files.txt`, so it deletes nothing foreign in `conf/`.

Prerequisite: **key login as root** from this node to the other two, without a
password prompt. The target is the `management_ip` from `cluster.conf`, so no
DNS entry is needed.

## Master and slave

Script and configuration are **identical** on every node and can be distributed
by git that way. What is node-specific follows at runtime:

```
MASTER_NODE=pf-node1
SSH_IDENTITY=/root/.ssh/id_pf_cluster
```

`MASTER_NODE` is a **hostname**, not a `master`/`slave` switch — every node
compares it against its own short name. Only there do the changing phases run;
everywhere else `status` and `preflight` are possible and everything else is
refused with a pointer to the master. Without `MASTER_NODE` any node may drive,
and the run warns once.

## The key

There is **exactly one** setting for it, and it is the same line on all three
nodes:

```
SSH_IDENTITY=/root/.ssh/id_pf_cluster
```

**Nothing node-specific is entered.** `SSH_IDENTITY` is a *path*; the *file* at
that path is the private key of that node. All three public keys sit in the
`authorized_keys` of all three nodes — which is why the configuration file stays
identical cluster-wide, and why the master moves by changing a single line.

The script **looks for nothing and guesses nothing**. With no key configured,
preflight offers to create one, distribute it and write the path back; the
password is asked for by `ssh-copy-id` itself and never passes through this
script. Declining, or working without a terminal, gets you the commands:

```bash
ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_pf_cluster
chmod 600 /root/.ssh/id_pf_cluster
ssh-copy-id -i /root/.ssh/id_pf_cluster.pub root@<management_ip of each other node>
# then in /usr/local/pf/conf/pf-cluster-upgrade.conf:
#   SSH_IDENTITY=/root/.ssh/id_pf_cluster
chmod 600 /usr/local/pf/conf/pf-cluster-upgrade.conf
```

**Permissions:** the private key `600` — ssh rejects anything more open without
a word, which then looks like a problem on the other side. The configuration
file `600` as well, because the webservices password may be in there. Preflight
checks both.

**Why no password login?** The script works with `BatchMode=yes` and opens
hundreds of short connections over its runtime — once a second while following a
detached operation. A password would have to be held in memory for hours and
handed over on every call. The key is distributed once instead.

The key itself is **tied to nothing** — not to hostname, IP or fingerprint. Only
`known_hosts` is bound to a place, and since the script connects to the
`management_ip`, its entries are there under the IP.

Before `upgrade-c`: **VM snapshots of all three nodes** (guide 12.4.1). From the
switch-over to C onwards they are the only way back.

---

## Tests

The test suite under `t/pf-cluster-upgrade/` drives every phase against a
fake cluster: `ssh`, `pfcmd`,
`systemctl`, `cluster/node`, `cluster/sync` and `do-upgrade.sh` are intercepted
and every command issued is recorded. What is then checked is the **actual
sequence of commands against what 12.4 prescribes**, among other things:

**Order against the guide.** The node order from `cluster.conf` is preserved,
the seven services of 12.4.4 restart in the guide's order on A *and* B, C is
upgraded before A and B are stopped, `packetfence-config` is never stopped, the
`UPGRADE_CLUSTER_SECONDARY` export and `do-upgrade.sh` share one shell (12.4.5),
`haproxy-admin` waits until both A and B are up (12.4.6), and
`--force-new-cluster` is withdrawn only after the resync.

**Nothing starts next to something else.** The configuration work on C happens
before A and B are stopped, their services still start only after them, a failed
resync of A leaves B's data untouched, and an unreachable node never counts as a
reachable database.

**The VIP arrives last.** keepalived is masked before the start, released only
once the other services are healthy, and never left masked — not even when the
VIP fails to arrive. A held-back keepalived is no outage, a dead one is. The VIP
is read from `[CLUSTER]` and never used as an ssh target. `reintegrate` stages
its starts the same way, and C is waited for exactly once on the normal path.

**Effects, not return codes.** Every step is checked for its effect, so an
ineffective step is caught even with exit status 0: a failed `configreload hard`
fails the start, a missing `conf/pf-release` gives its own message rather than
the ERR trap, an upgrade that installed nothing is reported, and `do-upgrade.sh`
gets its stdin from a file.

**State and configuration.** `--resume` repeats nothing and `--dry-run` issues
no command; the baseline distinguishes a known outage from a new one and
survives `--rebaseline` mid-procedure; the configuration file is parsed, so a
value followed by `&&`, an unknown key, or a substitution attempt is refused and
nothing in it is ever executed.

**Secrets and addresses.** A webservices password full of regex metacharacters
neither breaks the run nor appears in the log; SSH goes to the `management_ip`
while `bin/cluster/node` gets the hostname.

**`rollback`** deletes no data, aborts if MariaDB on C will not stop, stages the
start of A and B, and discards the markers of both upgrade phases.

**preflight** detects broken packages, too little disk space, locally modified
package files, and refuses to record a baseline mid-procedure.

Every `RS_*` remote block is syntax-checked; `RS_STOP_MARIADB`, where the
decision to send SIGKILL lives, is executed for real against all its cases.

```bash
cd t/pf-cluster-upgrade/ && make test
```

The run takes about half a minute (353 tests). Started by hand rather than
through `make`, close stdin (`bash pf-cluster-upgrade.tests </dev/null`):
two checks describe what happens *without* a terminal, and on a terminal they
would measure the terminal instead.

### What the tests do not cover

The script has been through several complete 15.1 → 15.2 runs on a three-node
cluster, the last of them without errors and with all three nodes `Synced/3`
at the end. The staged start and `wait_vip` were exercised there too.

What the fakes check is still only that the right commands go to the right
nodes in the right order — not how PacketFence reacts to them, and the `RS_*`
remote blocks are never executed by them at all. Every path those runs did not
happen to take is covered by tests alone. Specifically **not yet exercised on a
real cluster**:

- `clear_stale_failures` / `RS_CLEAR_FAILED`
- the `--resume` branch of the final `wait_services` in `upgrade-c`
- `rollback` as a whole, including `confirm_typed` and its staged start
- `ssh_identity_setup` — creating and distributing a key
- `--interactive-upgrade` and `rtty` — only ever run against a fake terminal
- the `rdetach` special branches: an operation already running, a vanished
  operation, and `DETACH_TIMEOUT`
- the `wait_galera` timeout and the aborts hanging off it
- `on_err` and `cleanup` — the test run disables both traps
- `--nodes`, `--os-update` and `--pioneer` as a complete run

Recommended way:

1. Run the test suite.
2. `preflight` on the production cluster — read-only.
3. Walk through every phase with `--dry-run`; the output shows every command.
4. The first real run on a test cluster.

The prompts of `do-upgrade.sh` are verified against the source of
`run-upgrade.sh`, not guessed.

The parser for `pfcmd service pf status` is verified against the real output of
a 15.1 node. Earlier versions expected `name|enabled|pid`; that format only
exists for `generateconfig`, not for `status`. The mistake there was not that
something crashed — the parser simply never found anything, and **every node
silently counted as healthy**. Hence the rule now: if the parser finds nothing
at all, that is an error and not a green light.

What remains to be watched on first use is the reading of the webservices
credentials from `pf.conf` for `cluster/sync`; if that fails, they are asked for
interactively.
