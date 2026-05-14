# Configurator Bypass Test Suite

## Overview

The `configurator_bypass` test suite provides a faster alternative to the full `configurator` REST API workflow. Instead of driving the configurator endpoints end-to-end (~20 HTTP calls + MariaDB bootstrap), this suite achieves the same end state by:

1. Pre-seeding configuration files (`pf.conf`, `pfconfig.conf`, `networks.conf`, etc.)
2. Running only the unavoidable side-effects directly (MariaDB init, schema load, OS network state, systemd links)
3. Never calling `/api/v1/configurator/*` endpoints

## Reference Implementation

This suite is derived from a source-verified audit of the configurator API endpoints, tracing each call through its controller to the underlying `pf::ConfigStore::*` backends. The audit (plan version v2) is documented in the feature branch PLAN.md.

## Scenario Steps

### Pre-flight (Step 00)
- Stop PF services (safety on re-run)
- Identify interface names (eth{N}) by their configured indices

### Configuration Seeding (Steps 01–02)
- **01**: Render and write `/usr/local/pf/conf/pf.conf`, `/usr/local/pf/conf/pfconfig.conf`, `/usr/local/pf/conf/networks.conf`, `/usr/local/pf/conf/pfqueue.conf`
- **02**: Write `/etc/resolv.conf` and bring up registration/isolation interfaces

### MariaDB Initialization (Step 10)
1. Start `packetfence-mariadb` systemd service
2. Run secure_installation equivalent (SQL):
   - Set root password
   - Drop anonymous users
   - Drop test database
   - Flush privileges
3. Create `pf` database with UTF-8 collation
4. Load schema: `cat /usr/local/pf/db/pf-schema.sql | mysql`
5. Load custom schemas: all `.sql` files in `/usr/local/pf/db/custom/` (sorted)
6. Create `pf` database user with full grants:
   - `SELECT, INSERT, UPDATE, DELETE, DROP, EXECUTE, LOCK TABLES, CREATE TEMPORARY TABLES` on `pf.*`
   - `CREATE, DROP` on `pf.radius_nas`
   - `BINLOG ADMIN` on `*.*`

### Configuration Application (Steps 20–50)
- **20**: Set admin password via Perl one-liner (`pf::password::default_hash_password`) → MySQL UPDATE
- **30**: Fetch Fingerbank API key from psonoci, write `/usr/local/fingerbank/conf/fingerbank.conf`
- **40**: Write `~vagrant/.my.cnf` (root credentials for unit tests)
- **50**: Restart MariaDB (timezone reload) and run `pfcmd configreload hard`

### Service Startup (Steps 60–80)
- **60**: Run `pfcmd service pf updatesystemd` (enables/disables services + daemon-reload)
- **70**: Restart `packetfence-config` (consume seeded pf.conf)
- **80**: Restart support services (`pfqueue-backend`, `pfqueue-go`, `haproxy-admin`, `packetfence-pfperl-api`) and start PF via `pfcmd service pf start`

### Validation (Step 99)
- Verify admin login works
- Verify Fingerbank API key is valid
- Verify all services are running

## Key Differences from Configurator Suite

| Aspect | Configurator | Bypass |
| --- | --- | --- |
| Interface setup | REST API PATCH /config/interface/* | Write pf.conf, networks.conf, ip link set |
| DNS setup | REST API PUT /config/system/dns_servers | Write /etc/resolv.conf |
| Database create | REST API POST /database/create | SQL CREATE DATABASE + schema load + cat db/pf-schema.sql |
| Database user | REST API POST /database/assign | SQL CREATE USER + GRANT |
| Admin password | REST API PATCH /user/admin/password | Perl one-liner → MySQL UPDATE |
| Systemd setup | REST API POST /service/pf/update_systemd | CLI pfcmd service pf updatesystemd |

## Configuration Scope

The bypass does **not**:
- Modify `/etc/sysconfig/network-scripts/ifcfg-*` (RHEL) or `/etc/network/interfaces` (Debian). These are assumed correct from the Vagrant baseline.
- Support cluster mode. Standalone profile only.
- Handle remote database / ProxySQL configuration.
- Introduce new variables; all values come from existing `configurator.*` keys in `t/venom/vars/all.yml`.

## Idempotency

Steps are designed to be idempotent where possible:
- Config file writes (pf.conf, networks.conf, etc.) overwrite previous versions.
- Database operations include `DROP IF EXISTS` and `IF NOT EXISTS` checks.
- Service restarts are safe to repeat.

Re-running the suite on a fresh box should produce the same end state; re-running on an already-configured box may fail on pre-existing state (e.g., "Database already exists").

## Performance

The bypass avoids the ~20 REST API round-trips and their attendant validation overhead, typically reducing setup time by 50%+ on the same hardware compared to the full configurator suite.

## Validation Against Configurator

To verify parity:
1. Run the full `configurator` suite on a fresh box; snapshot config files.
2. Reset the box; run `configurator_bypass` suite.
3. Snapshot the same config files.
4. Diff the files — differences should be limited to timestamps/key ordering or documented exceptions.
5. Run the same downstream tests (e.g., cli_login) on both setups to verify end-state equivalence.
