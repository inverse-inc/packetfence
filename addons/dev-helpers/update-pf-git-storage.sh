#!/bin/bash

set -o nounset -o pipefail -o errexit

source /usr/local/pf/addons/functions/configuration.functions

function exit_usage() {
  echo "------------------------------------------------------------------------------"
  echo "Usage:"
  echo "update-pfconf-git.sh /path/to/conf-git-repo/ pf-ref fingerbank-perl-client-ref"
  echo "Example: update-pfconf-git.sh /usr/local/pf/pfk8s-conf devel master"
  exit 1
}

dst_dir="$1"
pf_ref="$2"

if [ -z "$dst_dir" ] || ! [ -d "$dst_dir" ]; then
  echo "!!! - Missing destination directory or it doesn't exist"
  exit_usage
fi

if [ -z "$pf_ref" ]; then
  echo "!!! - Missing PF repo branch or tag name"
  exit_usage
fi

dst_dir=`echo $dst_dir | sed 's|/$||'`

tmpdir=`mktemp -d`

git clone -b $pf_ref https://github.com/inverse-inc/packetfence $tmpdir/packetfence

cd $tmpdir/packetfence
make configurations
make translation
cd -

cat <<EOT > add_files.txt
conf/local_secret
conf/unified_api_system_pass
conf/ssl/*
raddb/certs/*
fingerbank/conf/fingerbank.conf
EOT

files="`get_config_files`"

pristine_dir=$dst_dir-pristine-`date +%s`
mv $dst_dir $pristine_dir
mkdir -p $dst_dir
cp -a $pristine_dir/.git $dst_dir/.git
cp -a $tmpdir/packetfence/conf $dst_dir/
cp -a $tmpdir/packetfence/raddb $dst_dir/

mkdir -p $dst_dir/raddb/sites-enabled
cd $dst_dir/raddb/sites-enabled/
ln -s ../sites-available/status status
ln -s ../sites-available/dynamic-clients dynamic-clients
cd -

mkdir -p $dst_dir/fingerbank
cp -a $tmpdir/packetfence/addons/perl-client/conf $dst_dir/fingerbank/

for file in $files; do
  file=`echo $file | sed 's|^/usr/local/pf/||'`
  if [ -f $pristine_dir/$file ]; then
    cp $pristine_dir/$file $dst_dir/$file
  else
    echo "$pristine_dir/$file not found. Ignoring it.."
  fi
done

