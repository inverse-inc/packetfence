# UID/GID migration

This suite runs automatically in the existing `unit_tests` scenario, used by
the `unit_tests_deb12` and `unit_tests_el8` CI jobs.

The migration cases execute a temporary copy of `to-15.0-fix-uid-gid-pf-fingerbank.sh`, changing
only its installation path. Account, process, permission and service commands
are mocked; the test VM's accounts and services are not modified. Every case
sets `UPGRADE_CLUSTER_SECONDARY=yes`.

Coverage includes successful migration, failed account commands, verification
of the resulting IDs, processes remaining under real or effective UIDs, a
process exiting before it can be signalled, retrying after permission repairs
fail, service readiness failure, and accounts already migrated.

The strict-permission cases load the real `pfcmd fixpermissions` action with
isolated dependencies and temporary filesystem paths. They inject failed
`chown` and `chmod` operations, including a Fingerbank helper that returns
success despite failed repairs. They verify optional missing files, missing
required directories, dangling symlinks, and unchanged legacy command behavior.
These cases run as root, as in the existing unit-test scenario; numeric ownership
changes apply only to temporary fixture files.

Venom asserts the exit status, resulting account state, pending marker, and
which operations ran. Ownership assertions check that both the logs directory
and its contents are repaired to `root` and the new `pf` GID, including on retry.
The fixture removes its temporary files on exit.
Migration assertions also require `fixpermissions strict`, retain the pending
marker on failure, and verify that a retry finishes before clearing it.
This suite does not install packages or exercise a full version-to-version
upgrade or cluster reintegration.

To run just this suite on a test VM:

```bash
cd /usr/local/pf/t/venom
VENOM_COMMON_FLAGS='--var pfserver_test_dir=/usr/local/pf/t --output-dir=/tmp/venom-uid-gid' \
  ./venom-wrapper.sh test_suites/uid_gid_migration
```
