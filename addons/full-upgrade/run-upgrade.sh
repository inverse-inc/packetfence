#!/bin/bash

set -o nounset -o pipefail -o errexit

# functions come from addons/functions but are packaged
# inside full-upgrade directory to make full-upgrade package self-contained
source /usr/local/pf/addons/full-upgrade/helpers.functions
source /usr/local/pf/addons/full-upgrade/database.functions
source /usr/local/pf/addons/full-upgrade/configuration.functions

function get_libmariadb_dev() {
    libmariadb_version=$(dpkg -l libmariadb-dev|grep '^ii'|cut -d ':' -f 2 | cut -d '+' -f 1)
    if [ -n "${libmariadb_version}" ]; then
        echo ${libmariadb_version}
    else
        # 1 = false
        return 1
    fi
}

function get_packages_to_remove() {
    packages_to_remove='packetfence-captive-portal-javascript packetfence-doc packetfence-pfappserver-javascript'
    dpkg -s ${packages_to_remove} &>/dev/null
}


function backup_git_commit_id() {
  if [ `cat /usr/local/pf/conf/git_commit_id` = "%{git_commit}" ]; then
    echo "Broken git_commit_id detected, will have to guess which commit ID this build is based on"
    
    if [ `grep oauth2 conf/radiusd/packetfence-tunnel.example | wc -l` -eq 4 ]; then
      echo "Detected that this build was made before 6f33f85713ec329b73572a073ee6419bab7f8c5e."
      echo "Using the commit ID of v11.0.0 in conf/git_commit_id"
      echo -n a0c25391e58310b1b2be937013a9808bfd7c1071 > /usr/local/pf/conf/git_commit_id
    else
      echo "Detected that this build was made using 6f33f85713ec329b73572a073ee6419bab7f8c5e or a later commit."
      echo "Using the commit ID 6f33f85713ec329b73572a073ee6419bab7f8c5e in conf/git_commit_id"
      echo -n 6f33f85713ec329b73572a073ee6419bab7f8c5e > /usr/local/pf/conf/git_commit_id
    fi
  fi
  rm -f /usr/local/pf/conf/git_commit_id.preupgrade
  cp -a /usr/local/pf/conf/git_commit_id{,.preupgrade}
}

function backup_pf_release() {
  rm -f /usr/local/pf/conf/pf-release.preupgrade
  cp -a /usr/local/pf/conf/pf-release{,.preupgrade}
}

function upgrade_packetfence_package() {
  local include_os_update=$1
  canceled_update=no
  if is_rpm_based; then
    yum_upgrade_packetfence_package $include_os_update
  elif is_deb_based; then
    if get_packages_to_remove; then
        echo "Packages to remove detected"
        echo "OS upgrade can't be performed until ${packages_to_remove} are removed"
        include_os_update=no
        canceled_update=yes
    else
        echo "Unable to detect packages to remove"
    fi
    if get_libmariadb_dev; then
        if dpkg --compare-versions "${libmariadb_version}" le "10.5.15"; then
            echo "libmariadb-dev ${libmariadb_version} detected"
            echo "OS upgrade can't be performed until libmariadb-dev is uninstalled"
            include_os_update=no
            canceled_update=yes
        # cover fresh installations performed on Debian 11.6 before libmariadb-dev dependencies was removed
        else
            echo "libmariadb-dev ${libmariadb_version} detected"
            echo "OS upgrade can occur"
        fi
    else
        echo "Unable to detect a libmariadb-dev package, upgrade will continue"
    fi
    apt_upgrade_packetfence_package $include_os_update
  else
    echo "Unable to detect package manager to upgrade PacketFence"
    exit 1
  fi
}

function find_latest_stable() {
  OS=""
  if is_rpm_based; then
    OS="RHEL-8"
  elif is_deb_based; then
    OS="Debian-12"
  fi
  curl https://www.packetfence.org/downloads/PacketFence/latest-stable-$OS.txt
}

UPGRADE_TO="${UPGRADE_TO:-}"
function set_upgrade_to() {
  if [ -z "$UPGRADE_TO" ]; then
    latest_stable=`find_latest_stable`
    if prompt "The latest stable PacketFence version is $latest_stable, enter 'y' to upgrade to this version or 'n' to specify the version manually"; then
      UPGRADE_TO="$latest_stable"
    else
      echo -n "Please enter the PacketFence version to which you wish to upgrade: "
      read UPGRADE_TO
    fi
  fi
}

function apt_upgrade_packetfence_package() {
  set_upgrade_to
  echo "deb http://inverse.ca/downloads/PacketFence/debian/$UPGRADE_TO bookworm bookworm" > /etc/apt/sources.list.d/packetfence.list
  apt update
  if is_enabled $1; then
    apt-mark hold packetfence-upgrade
    DEBIAN_FRONTEND=noninteractive apt upgrade -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y
    apt-mark unhold packetfence-upgrade
  else
    DEBIAN_FRONTEND=noninteractive apt install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" packetfence -y
  fi
  DEBIAN_FRONTEND=noninteractive apt autoremove -q -y
  # OS upgrade was requested initially but has been canceled
  # We performed it now once packetfence packages have been upgraded
  if is_enabled $canceled_update; then
    apt-mark hold packetfence-upgrade
    DEBIAN_FRONTEND=noninteractive apt upgrade -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y
    apt-mark unhold packetfence-upgrade
  fi
}

function yum_upgrade_packetfence_package() {
  set_upgrade_to
  yum localinstall -y https://www.inverse.ca/downloads/PacketFence/RHEL8/packetfence-release-$UPGRADE_TO.el8.noarch.rpm
  yum clean all --enablerepo=packetfence
  if is_enabled $1; then
    yum update -y --enablerepo=packetfence --exclude=packetfence-upgrade --allowerasing
  else
    yum update packetfence -y --enablerepo=packetfence --allowerasing
  fi
}

function download_pristine_file() {
  git_commit_id="$1"
  file="$2"
  into="$3"
  url="https://raw.githubusercontent.com/inverse-inc/packetfence/$git_commit_id/$file"
  echo "Downloading $url"
  curl -f $url > $into 2>/dev/null
}

function handle_pkgnew_file() {
  file="$1"
  suffix="$2"
  escaped_suffix=`echo $suffix| perl -nle 'print quotemeta'`
  file=`echo $file | sed 's#^/usr/local/pf/##'`
  pkgnew_file="$file"

  previous_git_commit_id=`cat /usr/local/pf/conf/git_commit_id.preupgrade`
  
  non_pkgnew_file=`echo $file | sed 's/'$escaped_suffix'//'`
  patch_file="$non_pkgnew_file.upgrade-patch"
  backup_file="$non_pkgnew_file.upgrade-backup"
  pristine_file="$non_pkgnew_file.pristine"

  echo "Handling $suffix $file"
  if echo $file | grep '^conf/' > /dev/null; then
    download_pristine_file $previous_git_commit_id $non_pkgnew_file.example $pristine_file
  else
    download_pristine_file $previous_git_commit_id $non_pkgnew_file $pristine_file
  fi

  # diff returns 1 when there is a difference in the file and errexit makes it stop here. The dummy if allows the command to return a non-zero value
  if diff -Naur $pristine_file $non_pkgnew_file > $patch_file; then echo 1 > /dev/null ; fi
  sed -i 's#'`echo $pristine_file| perl -nle 'print quotemeta'`'#a/'$non_pkgnew_file'#' $patch_file
  sed -i 's# '`echo $non_pkgnew_file| perl -nle 'print quotemeta'`'# b/'$non_pkgnew_file'#' $patch_file

  echo "Moving $pkgnew_file -> $non_pkgnew_file and creating backup file $backup_file"
  cp -a $non_pkgnew_file $backup_file
  cp -a $pkgnew_file $non_pkgnew_file
  echo "Attempting a dry-run of the patch on $non_pkgnew_file"
  if ! patch -p1 -f --dry-run < $patch_file; then
    echo "Patching $non_pkgnew_file failed. You will keep the current configuration file ($non_pkgnew_file) BUT, please, check $pkgnew_file file if some modifications are needed in your config file $non_pkgnew_file.\nThis should be addressed manually after the upgrade is completed. Previous configuration is restored. Press enter to continue..."
    cp -a $backup_file $non_pkgnew_file
    read
  else
    echo "Dry-run completed successfully, applying the patch"
    patch -p1 -f < $patch_file
  fi
}

function handle_pkgnew_files() {
  if is_rpm_based; then
    suffix=".rpmnew"
  elif is_deb_based; then
    suffix=".dpkg-dist"
  else
    echo "Unable to detect package manager to upgrade PacketFence"
    exit 1
  fi

  echo "Checking for any $suffix files to process"

  files=`find /usr/local/pf/ -name '*'$suffix`
  for f in $files; do
    sub_splitter
    handle_pkgnew_file $f $suffix
  done
}

function hook_if_exists() {
  hook=/usr/local/pf/addons/full-upgrade/hooks/hook-$1
  if [ -f $hook ]; then
    main_splitter
    echo "Running upgrade hook $hook"
    $hook
    sub_splitter
  fi
}

cd /usr/local/pf/

hook_if_exists do-upgrade-start.sh

main_splitter
echo "Attempting to disable the monit service so it doesn't interfere with the upgrade"
systemctl disable monit || echo "Monit is not enabled or installed on this server"
echo "Attempting to stop the monit service so it doesn't interfere with the upgrade"
systemctl stop monit || echo "Monit is not enabled or installed on this server"

sub_splitter
echo "Stopping the PacketFence services"
/usr/local/pf/bin/pfcmd service pf stop

main_splitter
export_to="/root/packetfence-pre-upgrade-backup-`date '+%s'`.tgz"
echo "Generating full pre-upgrade backup to $export_to"
/usr/local/pf/addons/exportable-backup.sh -f $export_to

main_splitter
INCLUDE_OS_UPDATE="${INCLUDE_OS_UPDATE:-}"
if [ -z "$INCLUDE_OS_UPDATE" ]; then
  if prompt "Do you wish to perform the update of the operating system to the latest available patches during that process?"; then
    INCLUDE_OS_UPDATE="yes"
  else
    INCLUDE_OS_UPDATE="no"
  fi
fi

hook_if_exists do-upgrade-post-os-update-prompt.sh

main_splitter
echo "Backing up git_commit_id"
backup_git_commit_id

echo "Backing up pf-release"
backup_pf_release

hook_if_exists do-upgrade-pre-package-upgrade.sh

main_splitter
echo "Performing upgrade of the packages"
upgrade_packetfence_package $INCLUDE_OS_UPDATE

hook_if_exists do-upgrade-post-package-upgrade.sh

handle_devel_upgrade $UPGRADE_TO

UPGRADE_CLUSTER_SECONDARY="${UPGRADE_CLUSTER_SECONDARY:-}"
# Do not upgrade the database when upgrading secondary nodes of a cluster (the primary will sync its data to them)
if [ "$UPGRADE_CLUSTER_SECONDARY" != "yes" ]; then
  main_splitter
  db_name=`get_db_name /usr/local/pf/conf/pf.conf`
  upgrade_database $db_name

  hook_if_exists do-upgrade-post-db-upgrade.sh
fi

main_splitter
upgrade_configuration `egrep -o '[0-9]+\.[0-9]+\.[0-9]+$' /usr/local/pf/conf/pf-release.preupgrade`

hook_if_exists do-upgrade-post-config-upgrade.sh

main_splitter
handle_pkgnew_files

hook_if_exists do-upgrade-post-pkgnew-handling.sh

main_splitter
echo "Finalizing upgrade"

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
configreload

sub_splitter
echo "Updating systemd services state"
/usr/local/pf/bin/pfcmd service pf updatesystemd

main_splitter
echo "Completed the upgrade. Perform any necessary adjustments and restart PacketFence."
echo "If the kernel package was upgraded during this process, you should reboot this server."

hook_if_exists do-upgrade-upgrade-finalized.sh

