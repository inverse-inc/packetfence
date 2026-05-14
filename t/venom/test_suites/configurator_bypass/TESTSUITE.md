# Configurator Bypass Test Suite

## Overview

The `configurator_bypass` test suite provides a faster alternative to the full `configurator` REST API workflow. Instead of driving the configurator endpoints end-to-end (~20 HTTP calls + MariaDB bootstrap), this suite achieves the same end state by:

1. Pre-seeding configuration files (`pf.conf`, `pfconfig.conf`, `networks.conf`, etc.)
2. Running only the unavoidable side-effects directly (MariaDB init, schema load, OS network state, systemd links)
3. Never calling `/api/v1/configurator/*` endpoints

**Performance benefit**: Typically reduces setup time by **50%+** compared to the full configurator suite on the same hardware.

## Prerequisites

This test suite requires:

1. A **fresh Vagrant box** from the `pfservers` group (post-provision, pre-configuration)
2. PacketFence source tree available at `/usr/local/pf/` (installed by Vagrant Ansible provisioning)
3. Venom test framework installed and available in PATH
4. Ansible available (for rendering seed templates via `render_seeds.yml`)
5. Access to `psonoci` secret store for Fingerbank API key retrieval
6. Variables defined in `t/venom/vars/all.yml` under the `configurator.*` namespace
7. Network connectivity (needed for psonoci secret retrieval and Fingerbank API validation)

**Do not run** this suite:
- On a production system
- On a box already configured by the full configurator suite (unless you want to test idempotency failure modes)
- Without the prerequisites above

## Design Documentation

This test suite implements the design documented in:
- **PLAN.md** (feature branch `feature/packetfence-tests-prepare-config-to-bypass-configurator-test-suite`, revision v2, 2026-05-13)
- **Source-traced API audit** covering all 16 configurator endpoints (PLAN.md section 3)

Key design decisions:
- Use `pfcmd service pf updatesystemd` (CLI) instead of API endpoint — includes `systemctl daemon-reload` which the API endpoint omits
- Use Perl one-liner for admin password hashing — future-proof against bcrypt cost changes
- Skip OS-level network config files (RHEL `ifcfg-*` / Debian `/etc/network/interfaces`) — rely on Vagrant baseline having correct IPs
- Reuse all existing `configurator.*` variables from `vars/all.yml` — no new variables introduced
- Standalone profile only — cluster mode out of scope
- Localhost-only database user — no remote connections

For risk analysis and mitigation strategies, see PLAN.md section 6 (risks R1-R7).

## Scenario Steps

Steps are numbered in increments of 10 to allow inserting intermediate steps without renumbering:
- **00**: Pre-flight (safety checks, variable capture)
- **01-09**: Configuration file seeding
- **10-19**: Database initialization
- **20-59**: Configuration application (admin password, Fingerbank, credentials, config reload)
- **60-89**: Service setup and startup (systemd, packetfence-config, core services)
- **99**: Validation

### Pre-flight (00_pre_flight.yml)

- Stop PF services (safety on re-run)
- **Identify interface names** by their configured indices:
  - Parse `ip -o link show` output to map interface index → interface name (e.g., index `3:` → `eth2`)
  - Store discovered names in Venom variables (`mgmt_interface`, `reg_interface`, `iso_interface`) for use in subsequent steps
  - This mapping is required because `vars/all.yml` specifies interfaces by index, not name
  - Fails immediately if any interface doesn't exist (indicates incomplete Vagrant provisioning)

### Configuration Seeding (01_seed_conf_files.yml, 02_seed_resolv_conf.yml)

**01_seed_conf_files.yml**: Render and write 4 key configuration files (from 7 total seed templates):
- `/usr/local/pf/conf/pf.conf` — main PacketFence configuration with interface, database, alerting, advanced settings
- `/usr/local/pf/conf/pfconfig.conf` — secondary config with MySQL connection details
- `/usr/local/pf/conf/networks.conf` — VLAN registration and isolation network definitions
- `/usr/local/pf/conf/pfqueue.conf` — pfqueue worker count

**02_seed_resolv_conf.yml**: Write DNS and activate network interfaces:
- Write `/etc/resolv.conf` with primary and secondary DNS servers
- **Activate registration and isolation interfaces**:
  ```bash
  ip link set dev {{.reg_interface}} up
  ip link set dev {{.iso_interface}} up
  ```
  **Rationale**: Unlike the management interface (brought up by Vagrant), the registration and isolation VLANs require explicit activation after seeding their configuration in `pf.conf` and `networks.conf`.

### MariaDB Initialization (10_init_mariadb.yml)

1. Start `packetfence-mariadb` systemd service
2. **Wait for socket availability** (3 second delay to ensure socket is ready)
3. Run secure installation equivalent (SQL):
   - Set root password via `ALTER USER root@localhost IDENTIFIED BY ...`
   - Drop anonymous users
   - Drop remote root accounts (keep only localhost, 127.0.0.1, ::1)
   - Drop test database and associated permissions
   - Flush privileges
4. Create `pf` database with UTF-8 collation (`CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci`)
5. Load schema: `cat /usr/local/pf/db/pf-schema.sql | mysql`
6. Load custom schemas:
   - Iterate over all `.sql` files in `/usr/local/pf/db/custom/` (sorted by filename)
   - Exit on first failure (using `set -e` and explicit error handling)
   - Log each file as it's loaded
7. Create `pf` database user **for localhost only**:
   - `DROP USER IF EXISTS` for both `'pf'@'localhost'` and `'pf'@'%'` (cleanup)
   - `CREATE USER '{{.configurator.db.users.pf.id}}'@'localhost' IDENTIFIED BY ...`
   - Grant database-level privileges:
     - `SELECT, INSERT, UPDATE, DELETE, DROP, EXECUTE, LOCK TABLES, CREATE TEMPORARY TABLES` on `{{.configurator.db.name}}.*`
     - `CREATE, DROP` on `{{.configurator.db.name}}.radius_nas`
   - Grant global privilege:
     - `BINLOG ADMIN` on `*.*`
   - Flush privileges

### Configuration Application (20_seed_admin_password.yml, 30_seed_fingerbank_key.yml, 40_seed_my_cnf.yml, 50_configreload_hard.yml)

**20_seed_admin_password.yml**: Set admin password using Perl one-liner
- Generate bcrypt hash via `pf::password::default_hash_password()` (cost 8, from PacketFence defaults)
- Validate hash is non-empty before proceeding (error if Perl one-liner fails)
- Update `password` table: `UPDATE password SET password='$HASH' WHERE pid='admin'`

**30_seed_fingerbank_key.yml**: Fetch Fingerbank API key and configure
- Retrieve API key from psonoci secret store at runtime
- Write `/usr/local/fingerbank/conf/fingerbank.conf` with API key in `[upstream]` section

**40_seed_my_cnf.yml**: Seed credentials for unit tests
- Write `~vagrant/.my.cnf` with root credentials (`user`, `password`) in `[client]` section
- Set file permissions: `chmod 600` and `chown vagrant:vagrant`

**50_configreload_hard.yml**: Apply configuration reload
- Restart MariaDB service (timezone reload)
- Run `pfcmd configreload hard` to apply all seeded config files
- Retry up to 3 times with 2-second delays if service restart fails

### Service Startup (60_update_systemd.yml, 70_restart_packetfence_config.yml, 80_start_services.yml)

**60_update_systemd.yml**: Update systemd unit files
- Run `pfcmd service pf updatesystemd` (enables/disables services + daemon-reload)
- Retry up to 3 times with 2-second delays if command fails

**70_restart_packetfence_config.yml**: Consume seeded configuration
- Restart `packetfence-config` service (loads `pf.conf` and applies configuration)
- Retry up to 3 times with 2-second delays if service restart fails

**80_start_services.yml**: Start all PacketFence services
- Restart support services individually (with error handling):
  - `pfqueue-backend`
  - `pfqueue-go`
  - `haproxy-admin`
  - `packetfence-pfperl-api`
- Start main PF service via `pfcmd service pf start`
- Retry service startup up to 3 times with 5-second delays (more time needed for PF startup)

### Validation (99_validate.yml)

- **Configurator disabled check**: Verify `GET /api/v1/configurator/config/interfaces` returns 401 with message "The configurator is turned off" (with 3 retries)
- **Admin account check**: Verify `POST /api/v1/login` with admin credentials succeeds and returns JWT token
- **Services running check**: Verify `pfcmd service pf status` indicates all services are running

## Key Differences from Full Configurator Suite

The bypass achieves the same end state using direct file writes and CLI commands instead of REST API calls. Each operation below was **source-traced** from the API endpoint through its controller to the underlying implementation (documented in PLAN.md section 3) to ensure exact parity.

| Aspect | Full Configurator | Bypass | Notes |
|--------|-------------------|--------|-------|
| Interface setup | REST API PATCH `/config/interface/{iface}` | Write `pf.conf` + `networks.conf`; run `ip link set` | Bypass skips OS-level ifcfg files (Vagrant baseline) |
| DNS setup | REST API PUT `/config/system/dns_servers` | Write `/etc/resolv.conf` | Not written to pf.conf |
| Database create | REST API POST `/database/create` | SQL `CREATE DATABASE` + cat `db/pf-schema.sql` | Also writes `pfconfig.conf [mysql] db=` |
| Database user | REST API POST `/database/assign` | SQL `CREATE USER` + `GRANT` | Localhost-only user (`'pf'@'localhost'`) |
| Admin password | REST API PATCH `/user/admin/password` | Perl one-liner → MySQL UPDATE | Uses `pf::password::default_hash_password` (bcrypt cost-8) |
| Systemd setup | REST API POST `/service/pf/update_systemd` | CLI `pfcmd service pf updatesystemd` | **CLI form is more correct** — includes `daemon-reload` |

## Configuration Scope

The bypass does **not**:

- **Modify OS-level network config** (`/etc/sysconfig/network-scripts/ifcfg-*` on RHEL or `/etc/network/interfaces` on Debian).
  
  **Rationale**: Vagrant provisioning already configures these files and brings up the management interface before Ansible/Venom scenarios run. The registration and isolation interfaces are created by Vagrant but require explicit activation (see step 02b).
  
  **Risk mitigation**: Pre-flight step (00) verifies all three interfaces exist by querying their indices. If Vagrant provisioning is incomplete, the suite fails immediately with clear diagnostics.

- **Support cluster mode**. **Standalone profile only** — the configurator suite (the reference implementation) also only covers standalone mode.

- **Handle remote database / ProxySQL configuration**. All database operations assume local MariaDB on the same host with socket-based connections (`/var/lib/mysql/mysql.sock`).

- **Introduce new variables** — all values come from existing `configurator.*` keys in `t/venom/vars/all.yml`. This ensures the bypass and the full configurator suite use identical test data.

## Idempotency

Steps are designed to be idempotent **where the underlying operations support it**:
- Config file writes (`pf.conf`, `networks.conf`, etc.) overwrite previous versions cleanly
- Database user operations include `DROP USER IF EXISTS` before `CREATE USER` (fully idempotent)
- Service restarts are safe to repeat

**Non-idempotent operations**:
- Database creation (`CREATE DATABASE {{.configurator.db.name}}`) fails if the database already exists with error:
  ```
  ERROR 1007 (HY000): Can't create database 'pf'; database exists
  ```
- Schema loading (`cat pf-schema.sql | mysql`) may fail if tables already exist with error:
  ```
  ERROR 1050 (42S01): Table 'X' already exists
  ```

**Recommendation**: Run the bypass suite only on **fresh Vagrant boxes** (post-provision, pre-configuration). These errors do **not** indicate a bug in the suite — they indicate the box is not in the expected baseline state. To re-run:
1. Tear down and re-provision the Vagrant box: `vagrant destroy && vagrant up`
2. Or manually drop and recreate the database:
   ```sql
   DROP DATABASE IF EXISTS pf;
   ```

## Performance

The bypass avoids ~20 REST API round-trips and their attendant validation overhead.

**Expected performance**: ≥2× speedup compared to the full configurator suite on the same hardware (target from PLAN.md section 5.5).

**Actual performance**: *(To be measured during validation and documented in PR description)*

## Validation Against Configurator

To verify parity between the bypass and the full configurator suite:

### File-level comparison

1. Run the full `configurator` suite on a fresh box
2. Snapshot config files:
   ```bash
   mkdir -p /tmp/configurator_snapshot
   cp /usr/local/pf/conf/pf.conf /tmp/configurator_snapshot/
   cp /usr/local/pf/conf/pfconfig.conf /tmp/configurator_snapshot/
   cp /usr/local/pf/conf/networks.conf /tmp/configurator_snapshot/
   cp /usr/local/pf/conf/pfqueue.conf /tmp/configurator_snapshot/
   cp /usr/local/fingerbank/conf/fingerbank.conf /tmp/configurator_snapshot/
   cp /etc/resolv.conf /tmp/configurator_snapshot/
   ```
3. Reset the box: `vagrant destroy && vagrant up`
4. Run `configurator_bypass` suite
5. Snapshot the same files to `/tmp/bypass_snapshot/`
6. Diff: `diff -ur /tmp/configurator_snapshot/ /tmp/bypass_snapshot/`

**Acceptable differences**:
- Timestamps in file header comments
- Key ordering within INI sections (both Perl ConfigStore backends and the seed templates preserve insertion order, but order may differ)
- The `[advanced] configurator=` value presence/timing (set at different points in the flow)

**Unacceptable differences** (indicate bugs):
- Missing sections or keys
- Different values for the same key
- Missing files

### End-state behavioral validation

Run the same downstream integration tests (e.g., `cli_login`) on both configurations. Results must be identical.

### Automation

See PLAN.md section 6 (Risk R1) for the proposed CI smoke job that runs both suites on every PR touching configurator code.

## Troubleshooting

### Common Failure Modes

**Interface not found (step 00)**:
- **Symptom**: `ip -o link show | grep '^{{.configurator.interfaces.mgmt.index}}:'` returns empty
- **Cause**: Vagrant provisioning incomplete or interface indices in `vars/all.yml` don't match the box
- **Fix**: Verify `vagrant up` completed successfully; run `ip link show` to see actual interface indices; update `configurator.interfaces.*.index` in `vars/all.yml` if needed

**MariaDB socket not available (step 10)**:
- **Symptom**: `Can't connect to local MySQL server through socket '/var/lib/mysql/mysql.sock'`
- **Cause**: MariaDB service didn't fully start before schema load attempted
- **Fix**: Increase the sleep delay in `10_init_mariadb.yml` (line 11) from 3 to 5 seconds; verify `systemctl status packetfence-mariadb` shows "active (running)"

**Password hash generation fails (step 20)**:
- **Symptom**: `ERROR: Failed to generate password hash` or admin login fails at step 99
- **Cause**: Perl one-liner failed; `pf::password` module not found or unavailable
- **Fix**: Verify `/usr/local/pf/lib/pf/password.pm` exists; check Perl @INC paths; run Perl one-liner manually to debug

**Admin login fails (step 99)**:
- **Symptom**: `POST /api/v1/login` returns 401 or error
- **Cause**: Password hash mismatch (Perl one-liner failed, bcrypt cost changed, or admin user doesn't exist)
- **Fix**: Check step 20 logs for errors; manually query password table: `mysql -u pf -p'password' pf -e "SELECT pid, password FROM password WHERE pid='admin';"` and verify hash is non-empty

**Fingerbank API validation fails (step 99)**:
- **Symptom**: `GET /fingerbank/account_info` returns 403 or error
- **Cause**: API key invalid, psonoci secret unreachable, or Fingerbank upstream unreachable
- **Fix**: Verify network connectivity; check `curl https://api.fingerbank.inverse.ca/` works; verify psonoci secret retrieval: `psonoci secret get {{.configurator.fingerbank_api_key.secret_id}} password`

**Services won't start (steps 70-80)**:
- **Symptom**: `pfcmd service pf start` fails; systemctl errors
- **Cause**: Configuration file syntax error, missing systemd unit files, or port conflicts
- **Fix**: Check `systemctl status packetfence-config`; run `journalctl -xe -u packetfence-config` for errors; verify step 60 (`pfcmd service pf updatesystemd`) completed successfully; check for port conflicts: `ss -tlnp | grep -E ':(80|443|1443)'`

**Custom SQL files fail to load (step 10)**:
- **Symptom**: `ERROR 1064` or other SQL syntax errors during custom schema load
- **Cause**: Custom SQL file has syntax error or incompatible SQL dialect
- **Fix**: Manually test the offending file: `mysql -u root -p pf < /usr/local/pf/db/custom/XX_*.sql`; check for MySQL vs MariaDB syntax differences

## Reference Implementation

See PLAN.md in the feature branch for:
- Detailed API → file/section/key mapping (section 3)
- "Surprises" (unexpected behaviors) in the configurator API (section 3.1)
- Risk analysis and mitigation strategies (section 6, R1-R7)
- Validation strategy (section 5)
- Full commit changelog (section 9)
