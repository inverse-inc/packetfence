#!/bin/bash

set -o nounset -o pipefail -o errexit

source /usr/local/pf/addons/full-import/helpers.functions
source /usr/local/pf/addons/full-import/database.functions
source /usr/local/pf/addons/full-import/configuration.functions

function backup_git_commit_id() {
  cp -a /usr/local/pf/conf/git_commit_id{,.preupgrade}
}

function backup_pf_release() {
  cp -a /usr/local/pf/conf/pf-release{,.preupgrade}
}

function upgrade_packetfence_package() {
  if is_rpm_based; then
    yum_upgrade_packetfence_package
  elif is_deb_based; then
    apt_upgrade_packetfence_package
  else
    echo "Unable to detect package manager to upgrade PacketFence"
    exit 1
  fi
}

function find_latest_stable() {
  # TODO: remove this hack
  echo "11.1"
  return

  OS=""
  if is_rpm_based; then
    OS="RHEL-8"
  elif is_deb_based; then
    OS="Debian-11"
  fi
  curl https://www.packetfence.org/downloads/PacketFence/latest-stable-$OS.txt
}

upgrade_to=""
function set_upgrade_to() {
  latest_stable=`find_latest_stable`
  if prompt "The latest stable PacketFence version is $latest_stable, enter 'y' to upgrade to this version or 'n' to specify the version manually"; then
    upgrade_to="$latest_stable"
  else
    echo -n "Please enter the PacketFence version to which you wish to upgrade: "
    read upgrade_to
  fi
}

function apt_upgrade_packetfence_package() {
  set_upgrade_to
  echo "deb http://inverse.ca/downloads/PacketFence/debian/$upgrade_to bullseye bullseye" > /etc/apt/sources.list.d/packetfence.list
  # TODO: allow to update full OS or only PF
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" packetfence -y
}

function yum_upgrade_packetfence_package() {
  set_upgrade_to
  perl -MConfig::IniFiles -I/usr/local/pf/lib_perl/lib/perl5/ -e "\$c = Config::IniFiles->new( -file => '/etc/yum.repos.d/packetfence.repo') ; \$c->setval('packetfence', 'baseurl', 'http://inverse.ca/downloads/PacketFence/RHEL\$releasever/"$upgrade_to"/\$basearch') ; \$c->RewriteConfig"
  # TODO: allow to update full OS or only PF
  yum clean all --enablerepo=packetfence
  yum update packetfence -y --enablerepo=packetfence
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

main_splitter
echo "Backing up git_commit_id"
backup_git_commit_id

echo "Backing up pf-release"
backup_pf_release

main_splitter
echo "Performing upgrade of the packages"
upgrade_packetfence_package

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
echo "Completed the upgrade. Perform any necessary adjustments and restart PacketFence."
echo "If the kernel package was upgraded during this process, you should reboot this server."

