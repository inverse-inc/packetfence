#!/bin/bash
set -o nounset -o pipefail -o errexit

# Workaround for EOL of CentOS 8
# Use snapshot of deprecated repositories
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Linux-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://mirror.nsc.liu.se/centos-store|g' /etc/yum.repos.d/CentOS-Linux-*
