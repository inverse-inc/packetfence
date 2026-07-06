# backup_db_and_restore

## Requirements
MariaDB running and available using UNIX socket

## Scenario steps
1. Create user in DB using API and seed a config marker file
2. Backup files and DB with exportable-backup script, and check the archive
   carries the schema, data, grants and triggers
3. Delete user in DB using API
4. Restore the database only with `--db --restore-as-is` and check the DB
   triggers and routines survived the restore
5. Check that the user created at first step is still here using API
6. Restore the configuration only with `--conf --restore-as-is` and check the
   config marker is restored while the database is left untouched
7. Full restore with `--restore-as-is` and check both the user (database) and
   the config marker (configuration) are restored

## Teardown steps
1. Remove all backup files
2. Remove the config marker
3. Remove user created
