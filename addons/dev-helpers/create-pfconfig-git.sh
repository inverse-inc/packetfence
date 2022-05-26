#!/bin/bash

set -o nounset -o pipefail -o errexit

source /usr/local/pf/addons/functions/configuration.functions

function exit_usage() {
  echo "------------------------------------------------------------------------------"
  echo "Usage:"
  echo "create-pfconf-git.sh /path/to/conf-git-repo/ pf-ref fingerbank-perl-client-ref"
  echo "Example: update-pfconf-git.sh /usr/local/pf/pfk8s-conf devel master"
  exit 1
}

dst_dir="$1"
pf_ref="$2"
fb_ref="$3"

if [ -z "$dst_dir" ]; then
  echo "!!! - Missing destination directory"
  exit_usage
fi

if [ -z "$pf_ref" ]; then
  echo "!!! - Missing PF repo branch or tag name"
  exit_usage
fi

if [ -z "$fb_ref" ]; then
  echo "!!! - Missing Fingerbank perl client repo branch or tag name"
  exit_usage
fi

mkdir -p $dst_dir

tmpdir=`mktemp -d`

git clone -b $pf_ref https://github.com/inverse-inc/packetfence $tmpdir/packetfence
git clone -b $fb_ref https://github.com/fingerbank/perl-client $tmpdir/fingerbank

cd $tmpdir/packetfence
make conf/ssl/server.key
make conf/ssl/server.crt
make conf/local_secret
make raddb/certs/server.crt
make conf/unified_api_system_pass
make configurations
make translation
cd -

cd $tmpdir/fingerbank
perl db/upgrade.pl --database=db/fingerbank_Local.db
cp db/fingerbank_Local.db db/fingerbank_Upstream.db
cd -

cp -a $tmpdir/packetfence/conf $dst_dir/
cp -a $tmpdir/packetfence/raddb $dst_dir/

mkdir $dst_dir/fingerbank
cp -a $tmpdir/fingerbank/conf $dst_dir/fingerbank/

