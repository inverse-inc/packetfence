#!/bin/bash

ERROR=0

function download_and_check {
  u=$1
  dst=$2
  if [ `wget --server-response $u -O $dst 2>&1 | awk '/^  HTTP/{print $2}'` != "200" ] ; then
    echo "Failed to download $u"
    ERROR=1
    return 1
  else
    echo "Success downloading $u"
    return 0
  fi
}

function execute_and_check {
  cmd=$1
  msg=$2
  if ! `$cmd`; then
    echo "$msg"
    ERROR=1
  fi
}

dir="/tmp/pf-auto-check-update" && mkdir -p $dir && cd $dir && rm -fr *

script_registry_url="http://localhost:8000/index.txt"
script_registry_file="checks-script-registry"
script_dir="scripts"

mkdir -p $script_dir

download_and_check $script_registry_url $script_registry_file

#echo "" >> $script_registry_file

while read u; do
  tmp=`mktemp`
  echo "Downloading to $u"
  if ! download_and_check $u $tmp; then
    continue
  fi
  fname=$(grep -o '#fname:.*' $tmp | grep -o ':.*' | tr ':' '.')
  if [ -z $fname ]; then
    echo "Failed to determine filename for $u"
    ERROR=1
  fi
  echo "Placing $u in $fname"
  execute_and_check "mv $tmp $script_dir/$fname" "Cannot place file in script directory"
  execute_and_check "chmod +x $script_dir/$fname" "Cannot set executable bit on script"
done <$script_registry_file



