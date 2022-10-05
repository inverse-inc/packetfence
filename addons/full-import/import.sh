#!/bin/bash

set -o nounset -o pipefail -o errexit

source /usr/local/pf/addons/functions/helpers.functions
source /usr/local/pf/addons/functions/database.functions
source /usr/local/pf/addons/functions/configuration.functions

function cleanup() {
  echo "Cleaning temporary directory"
  rm -fr $extract_dir
  if [ "$mariabackup_installed" = "true" ]; then
      uninstall_mariabackup $pf_version_in_export
  fi
}

prepare_import() {
    dump_path="$1"

    if ! [ -f "$dump_path" ]; then
        echo "Please specify a valid archive to extract"
        echo "Usage: import.sh /path/to/export.tgz"
        exit 1
    fi

    extract_dir=`mktemp -d`

    trap cleanup EXIT

    cp -a $dump_path $extract_dir/export.tgz

    pushd $extract_dir/

    main_splitter

    echo "Extracting archive..."
    tar -xf export.tgz

    echo "Found the following content in the archive:"
    ls -l | grep -v export.tgz

    main_splitter
    files_dump=`ls packetfence-files-*`
    echo "Found files dump '$files_dump'"

    echo "Extracting files dump"
    tar -xf $files_dump

    main_splitter

    db_dump=`ls packetfence-db-dump-*`
    echo "Found compressed database dump '$db_dump'"
    gunzip $db_dump
    db_dump=`ls packetfence-db-dump-*`
    echo "Uncompressed database dump '$db_dump'"

    main_splitter
    echo "Get PF version in PacketFence export"
    pf_version_in_export=$(get_pf_version_in_export $extract_dir)
    echo "$pf_version_in_export"

    main_splitter
    echo "Stopping PacketFence services"
    systemctl cat monit >/dev/null 2>&1 && (systemctl stop monit ; systemctl disable monit)
    systemctl isolate packetfence-base
    systemctl stop packetfence-galera-autofix
}

import_db() {
    main_splitter
    if echo "$db_dump" | grep '\.sql$' >/dev/null; then
        echo "The database dump uses mysqldump"
        #TODO /tmp/grants.sql should be included in the export
        import_mysqldump grants.sql $db_dump usr/local/pf/conf/pf.conf
    elif echo "$db_dump" | grep '\.xbstream$' >/dev/null; then
        echo "The database uses mariabackup"
	# permit to remove mariabackup if everything goes well
	# or to uninstall it if a failure occurs during installation
        if install_mariabackup $pf_version_in_export; then
	    mariabackup_installed=true
	else
	    uninstall_mariabackup $pf_version_in_export
	    exit 1
	fi
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
}

import_config() {
    main_splitter
    restore_config_files `pwd`

    main_splitter
    handle_network_change

    main_splitter
    restore_profile_templates

    main_splitter
    upgrade_imported_configuration

    main_splitter
    if [ "$do_adjust_config" -eq 1 ]; then
        echo "Performing adjustments on the configuration"
    else
	echo "Skipping adjustments on the configuration"
    fi

    main_splitter
    echo "Restoring certificates"
    restore_certificates
}

finalize_import() {
    main_splitter
    echo "Finalizing import"

    sub_splitter
    echo "Applying fixpermissions"
    /usr/local/pf/bin/pfcmd fixpermissions

    sub_splitter
    echo "Restarting packetfence-redis-cache"
    systemctl restart packetfence-redis-cache

    sub_splitter
    echo "Restarting packetfence-config"
    systemctl restart packetfence-config

    sub_splitter
    echo "Reloading configuration"
    /usr/local/pf/bin/pfcmd configreload hard

    main_splitter
    echo "Completed import of the database and the configuration! Complete any necessary adjustments and restart PacketFence"

    # Done with everything, time to cleanup!
    systemctl cat monit > /dev/null 2>&1 && systemctl enable monit
    popd > /dev/null
}

help(){
    cat <<-EOF
$0 imports a PacketFence export

Usage: $0 -f /path/to/export.tgz [OPTION]...

Options:
 -f,--file                  Import a PacketFence export (mandatory)
 -h,--help                  Display this help
 --db			    Import only database from PacketFence export
 --conf			    Import only configuration from PacketFence export
 --skip-adjust-conf	    Don't run adjustments on configuration (only use it if you know what you are doing)

EOF
}

#############################################################################
### Handle args
#############################################################################
do_full_import=1
do_db_import=0
do_config_import=0
do_adjust_config=1
mariabackup_installed=false
EXPORT_FILE=${EXPORT_FILE:-}

# Parse option
# TEMP=$(getopt -o f:h --long file:,help,db,conf \
    #      -n "$0" -- "$@") || (echo "getopt failed." && exit 1)
TEMP=$(getopt -o f:h --long file:,help,db,conf,skip-adjust-conf \
     -n "$0" -- "$@") || (echo "getopt failed." && exit 1)

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -f|--file)
	    # first shift is mandatory to get file path
	    shift 
            EXPORT_FILE="$1" ; shift 
            ;;
        -h|--help)
            help ; exit 0 ; shift 
            ;;
        --db)
            do_db_import=1 ; do_full_import=0 ; shift 
            ;;
        --conf)
            do_config_import=1 ; do_full_import=0 ; shift
            ;;
        --skip-adjust-conf)
            do_adjust_config=0 ; shift
            ;;
        --) 
            shift ; break 
            ;;
        *) 
            echo "Wrong usage !" ; help ; exit 1 
            ;;
    esac
done

if [ -z "$EXPORT_FILE" ]; then
    echo "A path to a PacketFence export is mandatory"
    help
    exit 1
fi

if [ ! -f "$EXPORT_FILE" ]; then
    echo "$EXPORT_FILE is not a regular file"
    exit 1
fi

#############################################################################
### Import process
#############################################################################
prepare_import $EXPORT_FILE

case "$do_full_import" in
    1)    import_db ; import_config ;;
    0)    [ "$do_db_import" -eq 1 ] && import_db
          [ "$do_config_import" -eq 1 ] && import_config
	  ;;
    *)    echo "Unexpected result" ; exit 1
	  ;;
esac

finalize_import
