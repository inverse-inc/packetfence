#!/bin/bash

source /usr/local/pf/addons/monit/monitoring-scripts/setup.sh

ERROR=0

function download_and_check {
  u="$1.sig"
  dst="$2"
  may_not_exist="${3:-"0"}"
  tmpencrypted=`mktemp`

  if [ "`curl -sD - $u -o $tmpencrypted 2>&1 | awk '/^HTTP/{print $2}'`" != "200" ] ; then
    echo "Failed to download $u"
    rm $tmpencrypted
    if [ $may_not_exist -eq 1 ];then
      return 0
    else
      ERROR=1
      return 1
    fi
  else
    echo "Success downloading $u"
    echo "Decrypting $tmpencrypted to $dst"
    if ! gpg --batch --yes --output $dst --decrypt $tmpencrypted; then
      echo "Failed to validate signature of $u"
      ERROR=1
      rm $tmpencrypted
      return 1
    fi
    rm $tmpencrypted
    return 0
  fi
}

function execute_and_check {
  cmd=$1
  msg=$2
  if ! `$cmd`; then
    echo "$msg"
    ERROR=1
    return 1
  else
    return 0
  fi
}

dir="/tmp/pf-auto-check-update" && mkdir -p $dir && cd $dir && rm -fr *

id -u pf-monitoring || execute_and_check "useradd pf-monitoring -s /bin/bash"
execute_and_check "usermod -a -G pf pf-monitoring"

execute_and_check "mkdir -p $script_dir"
execute_and_check "chown root:pf-monitoring $script_dir"
execute_and_check "chmod 0750 $script_dir"

download_and_check $script_registry_url $script_registry_file
download_and_check $global_vars_url $global_vars_file
download_and_check $global_ignores_url $global_ignores_file

download_and_check $uuid_vars_url $uuid_vars_file 1
download_and_check $uuid_ignores_url $uuid_ignores_file 1

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
    continue
  fi
  echo "Placing $u in $fname"
  execute_and_check "mv $tmp $script_dir/$fname" "Cannot place file in script directory"
  execute_and_check "chmod ug+rx $script_dir/$fname" "Cannot set executable bit on script"
  execute_and_check "chown pf-monitoring:pf-monitoring $script_dir/$fname" "Cannot set executable bit on script"
done <$script_registry_file

if [ $ERROR -ne 0 ]; then
  echo "Something failed in the update process...."
  exit 1
else
  echo "Update completed successfully"
  exit 0
fi

