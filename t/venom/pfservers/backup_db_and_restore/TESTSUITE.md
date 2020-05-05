# backup_db_and_restore

## Requirements
MariaDB running and available usign UNIX socket

## Scenario steps
1. Inject data in DB
2. Backup files and DB with backup script
3. Check DB file has been created by backup script
4. Destroy DB
5. Recreate DB based on current schema
6. Restore data from backup DB file
7. Check that data created at first step is still here

## Teardown steps
1. Remove data injected if they can impact other test suites
