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
  check_code $?
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

function yum_upgrade_packetfence_package() {
  set_upgrade_to
  perl -MConfig::IniFiles -I/usr/local/pf/lib_perl/lib/perl5/ -e "\$c = Config::IniFiles->new( -file => '/etc/yum.repos.d/packetfence.repo') ; \$c->setval('packetfence', 'baseurl', 'http://inverse.ca/downloads/PacketFence/RHEL\$releasever/"$upgrade_to"/\$basearch') ; \$c->RewriteConfig"
  check_code $?
  # TODO: allow to update full OS or only PF
  yum update packetfence --enablerepo=packetfence
}

function download_pristine_file() {
  git_commit_id="$1"
  file="$2"
  into="$3"
  url="https://raw.githubusercontent.com/inverse-inc/packetfence/$git_commit_id/$file"
  echo "Downloading $url"
  curl -f $url > $into 2>/dev/null
}

function handle_rpmnew_file() {
  file="$1"
  file=`echo $file | sed 's#^/usr/local/pf/##'`
  rpmnew_file="$file"

  previous_git_commit_id=`cat /usr/local/pf/conf/git_commit_id.preupgrade`
  
  echo "Handling rpmnew $file"
  non_rpmnew_file=`echo $file | sed 's/.rpmnew//'`
  if echo $file | grep '^conf/' > /dev/null; then
    download_pristine_file $previous_git_commit_id $non_rpmnew_file.example $non_rpmnew_file.pristine 
    check_code $?
  else
    download_pristine_file $previous_git_commit_id $non_rpmnew_file $non_rpmnew_file.pristine 
    check_code $?
  fi

  # diff returns 1 when there is a difference in the file and errexit makes it stop here. The dummy if allows the command to return a non-zero value
  if diff -Naur $non_rpmnew_file.pristine $non_rpmnew_file > $non_rpmnew_file.upgrade-patch; then echo 1 > /dev/null ; fi
  sed -i 's#'$non_rpmnew_file'\.pristine#a/'$non_rpmnew_file'#' $non_rpmnew_file.upgrade-patch
  sed -i 's# '$non_rpmnew_file'# b/'$non_rpmnew_file'#' $non_rpmnew_file.upgrade-patch

  echo "Moving $rpmnew_file -> $non_rpmnew_file and creating backup file $non_rpmnew_file.upgrade-backup"
  cp -a $non_rpmnew_file $non_rpmnew_file.upgrade-backup
  check_code $?
  cp -a $rpmnew_file $non_rpmnew_file
  check_code $?
  echo "Patching $non_rpmnew_file"
  if ! patch -p1 < $non_rpmnew_file.upgrade-patch; then
    # TODO: store these somewhere so that they can be displayed at the end of the upgrade
    echo "Patching $non_rpmnew_file failed. Will put the rpmnew file in place. This should be addressed manually after the upgrade is completed."
    cp -a $non_rpmnew_file.upgrade-backup $non_rpmnew_file
  fi
}

function handle_rpmnew_files() {
  files=`find /usr/local/pf/ -name '*.rpmnew'`
  for f in $files; do
    handle_rpmnew_file $f
  done
}

main_splitter
echo "Backing up git_commit_id"
backup_git_commit_id
check_code $?

echo "Backing up pf-release"
backup_pf_release
check_code $?

main_splitter
echo "Performing upgrade of the packages"
upgrade_packetfence_package

main_splitter
db_name=`get_db_name /usr/local/pf/conf/pf.conf`
upgrade_database $db_name
check_code $?

main_splitter
upgrade_configuration `egrep -o '[0-9]+\.[0-9]+\.[0-9]+$' /usr/local/pf/conf/pf-release.preupgrade`
check_code $?

main_splitter
handle_rpmnew_files
check_code $?

main_splitter
echo "Completed the upgrade. Perform any necessary adjustments and restart PacketFence."
echo "If the kernel package was upgraded during this process, you should reboot this server."

