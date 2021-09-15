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
echo "Completed the upgrade. Perform any necessary adjustments and restart PacketFence."
echo "If the kernel package was upgraded during this process, you should reboot this server."

