#!/bin/bash

if [ -z "$1" ]; then
  echo "Missing output parameter"
  echo "Usage export.sh /path/to/export.tgz [--force]"
  exit 1
fi

set -o nounset -o pipefail -o errexit

source /usr/local/pf/addons/functions/helpers.functions
source /usr/local/pf/addons/functions/database.functions

output="$1"
BACKUP_DB_FILENAME='packetfence-db-dump-*'
BACKUP_CONF_FILENAME='packetfence-conf-dump-*'

echo "Search last database dump available."
last_db_dump=`find /root/backup -name $BACKUP_DB_FILENAME -printf "%T@ %p\n" | sort -n | tail -1 | awk '{ print $2 }'`

if [ -z "$last_db_dump" ]; then
  echo "Unable to find a database dump."
  exit 1
fi

echo "Search last config dump available."
last_conf_dump=`find /root/backup -name $BACKUP_CONF_FILENAME -printf "%T@ %p\n" | sort -n | tail -1 | awk '{ print $2 }'`

if [ -z "$last_conf_dump" ]; then
  echo "Unable to find a config dump."
  exit 1
fi

build_dir=`mktemp -d`

function cleanup() {
  echo "Cleaning temporary directory"
  rm -fr $build_dir
}
trap cleanup EXIT

pushd $build_dir

main_splitter
echo "Copying dump files to temporary export directory"
cp -a $last_db_dump $build_dir/
cp -a $last_conf_dump $build_dir/

mariadb_args=""

if echo "$last_db_dump" | grep '\.sql.gz$' >/dev/null; then
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
perl -I/usr/local/pf/lib_perl/lib/perl5/ -I/usr/local/pf/lib -Mpf::file_paths -e 'print join("\n", @pf::file_paths::stored_config_files) . "\n"' > stored_config_files.txt

main_splitter
echo "Computing additional files that are referenced in the configuration"
add_files="`/usr/local/pf/addons/full-import/find-extra-files.pl`"
for f in $add_files; do
  if dirname $f | grep '^/usr/local/pf/' > /dev/null; then
    echo "Found reference to external file that is in the PF directory ($f)"
    echo $f >> add_files.txt
  else
    echo "Found reference to external file that is outside the PF directory ($f)"
    base_dir=`dirname $f`
    mkdir -p ./$base_dir
    check_code $?
    cp -a $f ./$base_dir/
    check_code $?
    echo $f >> add_files.txt
  fi
done

main_splitter
echo "Creating exportable backup archive"
tar -cvzf $output *
check_code $?

main_splitter
echo "Done backuping to $output"

popd > /dev/null

