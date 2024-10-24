# backup_db_and_restore

## Requirements
MariaDB running and available using UNIX socket

## Scenario steps
1. Create user in DB using API
2. Backup files and DB with exportable-backup script
7. Import only db from backup
8. Check that user created at first step is still here using API: validate
   that application is running after DB restore

## Teardown steps
1. Remove all backup files
2. Remove user created
