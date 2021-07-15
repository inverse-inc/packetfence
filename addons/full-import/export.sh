#!/bin/bash

source /usr/local/pf/addons/full-import/helpers.functions
source /usr/local/pf/addons/full-import/database.functions

output="$1"

if [ -z "$output" ]; then
  echo "Missing output parameter"
  echo "Usage export.sh /path/to/export.tgz [--force]"
  exit 1
fi

db_dump=`find /root/backup/ -name 'packetfence-db-dump-*' -mtime -1 | tail -1`

if [ -z "$db_dump" ]; then
  echo "Unable to find a database dump that was done in the last 24 hours. Add --force to ignore this."
  exit 1
fi

files_dump=`find /root/backup/ -name 'packetfence-files-dump-*' -mtime -1 | tail -1`

if [ -z "$files_dump" ]; then
  echo "Unable to find a database dump that was done in the last 24 hours. Add --force to ignore this."
  exit 1
fi

build_dir=`mktemp -d`

pushd $build_dir

main_splitter
echo "Copying dump files to temporary export directory"
cp -a $db_dump $build_dir/
cp -a $files_dump $build_dir/

if echo "$db_dump" | grep '\.sql.gz$' >/dev/null; then
  if ! test_db_connection_no_creds; then
    echo -n "Please enter the root password for MariaDB:"
    read -s mariadb_root_pass
    mariadb_args="$mariadb_args -p$mariadb_root_pass"
  fi

  echo "Database dump uses mysqldump. Exporting the grants from the database. Enter the MariaDB root password if prompted to"
  mysql $mariadb_args --skip-column-names -A -e"SELECT CONCAT('SHOW GRANTS FOR ''',user,'''@''',host,''';') FROM mysql.user WHERE user<>''" | mysql $mariadb_args --skip-column-names -A | sed 's/$/;/g' > grants.sql
fi

main_splitter
echo "Building list of configuration files for this current version"
perl -I/usr/local/pf/lib_perl5/lib -I/usr/local/pf/lib -Mpf::file_paths -e 'print join("\n", @pf::file_paths::stored_config_files) . "\n"' > stored_config_files.txt

main_splitter
echo "Creating export archive"
tar -cvzf $output *
check_code $?

main_splitter
echo "Done exporting to $output"

popd > /dev/null

rm -fr $build_dir

