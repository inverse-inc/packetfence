#!/bin/bash

set -o nounset -o pipefail -o errexit

source /usr/local/pf/addons/full-import/helpers.functions
source /usr/local/pf/addons/full-import/database.functions
source /usr/local/pf/addons/full-import/configuration.functions

dump_path="$1"

if ! [ -f "$dump_path" ]; then
  echo "Please specify a valid archive to extract"
  echo "Usage: import.sh /path/to/export.tgz"
  exit 1
fi

extract_dir=`mktemp -d`

function cleanup() {
  echo "Cleaning temporary directory"
  rm -fr $extract_dir
}
trap cleanup EXIT

cp -a $dump_path $extract_dir/export.tgz
check_code $?

pushd $extract_dir/
check_code $?

main_splitter

echo "Extracting archive..."
tar -xf export.tgz
check_code $?

echo "Found the following content in the archive:"
ls -l | grep -v export.tgz

main_splitter
files_dump=`ls packetfence-files-*`
echo "Found files dump '$files_dump'"

echo "Extracting files dump"
tar -xf $files_dump
check_code $?

main_splitter

db_dump=`ls packetfence-db-dump-*`
echo "Found compressed database dump '$db_dump'"
gunzip $db_dump
check_code $?
db_dump=`ls packetfence-db-dump-*`
echo "Uncompressed database dump '$db_dump'"

main_splitter
echo "Stopping PacketFence services"
systemctl cat monit >/dev/null 2>&1 && (systemctl stop monit ; systemctl disable monit)
systemctl isolate packetfence-base
check_code $?
systemctl stop packetfence-galera-autofix
check_code $?

if echo "$db_dump" | grep '\.sql$' >/dev/null; then
  echo "The database dump uses mysqldump"
  #TODO /tmp/grants.sql should be included in the export
  import_mysqldump grants.sql $db_dump usr/local/pf/conf/pf.conf
elif echo "$db_dump" | grep '\.xbstream$' >/dev/null; then
  echo "The database uses mariabackup"
  import_mariabackup $db_dump
else
  echo "Unable to detect format of the database dump"
  exit 1
fi

#TODO: check the version of the export, we want to support only 10.3.0 and above
#TODO: check if galera is enabled and stop if its the case

main_splitter
db_name=`get_db_name usr/local/pf/conf/pf.conf`
upgrade_database $db_name
check_code $?

main_splitter
restore_config_files `pwd`
check_code $?

main_splitter
handle_network_change
check_code $?

main_splitter
restore_profile_templates
check_code $?

main_splitter
upgrade_imported_configuration
check_code $?

main_splitter
echo "Performing adjustments on the configuration"
adjust_configuration

main_splitter
echo "Finalizing import"

sub_splitter
echo "Applying fixpermissions"
/usr/local/pf/bin/pfcmd fixpermissions
check_code $?

sub_splitter
echo "Restarting packetfence-config"
systemctl restart packetfence-config
check_code $?

sub_splitter
echo "Reloading configuration"
/usr/local/pf/bin/pfcmd configreload hard
check_code $?

main_splitter
echo "Restoring certificates"
restore_certificates
check_code $?

main_splitter
echo "Completed import of the database and the configuration! Complete any necessary adjustments and restart PacketFence"

# Done with everything, time to cleanup!
systemctl cat monit > /dev/null 2>&1 && systemctl enable monit
popd > /dev/null

