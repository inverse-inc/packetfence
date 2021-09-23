#!/bin/bash

set -o nounset -o pipefail -o errexit

source /usr/local/pf/addons/full-import/helpers.functions
source /usr/local/pf/addons/full-import/database.functions
source /usr/local/pf/addons/full-import/configuration.functions

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
  yes | cp -a /usr/local/pf/conf/git_commit_id{,.preupgrade}
}

function backup_pf_release() {
  yes | cp -a /usr/local/pf/conf/pf-release{,.preupgrade}
}

function upgrade_packetfence_package() {
  if is_rpm_based; then
    yum_upgrade_packetfence_package $1
  elif is_deb_based; then
    apt_upgrade_packetfence_package $1
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
    OS="Debian-11"
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
  echo "deb http://inverse.ca/downloads/PacketFence/debian/$UPGRADE_TO bullseye bullseye" > /etc/apt/sources.list.d/packetfence.list
  # TODO: allow to update full OS or only PF
  apt update
  if is_enabled $1; then
    DEBIAN_FRONTEND=noninteractive apt upgrade -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y
  else
    DEBIAN_FRONTEND=noninteractive apt install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" packetfence -y
  fi
}

function yum_upgrade_packetfence_package() {
  set_upgrade_to
  perl -MConfig::IniFiles -I/usr/local/pf/lib_perl/lib/perl5/ -e "\$c = Config::IniFiles->new( -file => '/etc/yum.repos.d/packetfence.repo') ; \$c->setval('packetfence', 'baseurl', 'http://inverse.ca/downloads/PacketFence/RHEL\$releasever/"$UPGRADE_TO"/\$basearch') ; \$c->RewriteConfig"
  yum clean all --enablerepo=packetfence
  if is_enabled $1; then
    yum update -y --enablerepo=packetfence
  else
    yum update packetfence -y --enablerepo=packetfence
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
    # TODO: store these somewhere so that they can be displayed at the end of the upgrade
    echo "Patching $non_pkgnew_file failed. Will put the $suffix file in place. This should be addressed manually after the upgrade is completed."
    cp -a $pkgnew_file $non_pkgnew_file
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

ALLOW_CLUSTER_UPGRADE="${ALLOW_CLUSTER_UPGRADE:-no}"
if ! is_enabled $ALLOW_CLUSTER_UPGRADE && is_cluster; then
  echo "Upgrading a cluster is not supported by this tool at the moment."
  echo "You can use it **at your own risk** by setting the following environment variable:"
  echo "  export ALLOW_CLUSTER_UPGRADE=yes"
  exit 1
fi

main_splitter
INCLUDE_OS_UPDATE="${INCLUDE_OS_UPDATE:-}"
if [ -z "$INCLUDE_OS_UPDATE" ]; then
  if prompt "Do you wish to perform the update of the operating system to the latest available patches during that process?"; then
    INCLUDE_OS_UPDATE="yes"
  else
    INCLUDE_OS_UPDATE="no"
  fi
fi

main_splitter
echo "Backing up git_commit_id"
backup_git_commit_id

echo "Backing up pf-release"
backup_pf_release

main_splitter
echo "Performing upgrade of the packages"
upgrade_packetfence_package $INCLUDE_OS_UPDATE

main_splitter
db_name=`get_db_name /usr/local/pf/conf/pf.conf`
upgrade_database $db_name

main_splitter
upgrade_configuration `egrep -o '[0-9]+\.[0-9]+\.[0-9]+$' /usr/local/pf/conf/pf-release.preupgrade`

main_splitter
handle_pkgnew_files

main_splitter
echo "Finalizing upgrade"

sub_splitter
echo "Applying fixpermissions"
/usr/local/pf/bin/pfcmd fixpermissions

sub_splitter
echo "Restarting packetfence-config"
systemctl restart packetfence-config

sub_splitter
echo "Reloading configuration"
/usr/local/pf/bin/pfcmd configreload hard

sub_splitter
echo "Updating systemd services state"
/usr/local/pf/bin/pfcmd service pf updatesystemd

main_splitter
echo "Completed the upgrade. Perform any necessary adjustments and restart PacketFence."
echo "If the kernel package was upgraded during this process, you should reboot this server."

