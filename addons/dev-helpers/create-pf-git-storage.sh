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

if [ -z "$dst_dir" ]; then
  echo "!!! - Missing destination directory"
  exit_usage
fi

if [ -z "$pf_ref" ]; then
  echo "!!! - Missing PF repo branch or tag name"
  exit_usage
fi

mkdir -p $dst_dir

tmpdir=`mktemp -d`

git clone -b $pf_ref https://github.com/inverse-inc/packetfence $tmpdir/packetfence

## Happens in the PF dir (chdir)
cd $tmpdir/packetfence

make conf/ssl/server.pem
make conf/local_secret
make raddb/certs/server.crt
make raddb/sites-enabled
make conf/unified_api_system_pass
make conf/system_init_key
make configurations
make translation

cat <<EOF > conf/pf.conf
[advanced]
configurator=disabled

[interface virtualmgmt]
ip=127.127.127.127
mask=255.255.255.255
type=management,portal
EOF

cd -
## End of the commands in the PF dir

cd  $tmpdir/packetfence/addons/perl-client/
perl db/upgrade.pl --database=db/fingerbank_Local.db
cp db/fingerbank_Local.db db/fingerbank_Upstream.db
cd -

cp -a $tmpdir/packetfence/conf $dst_dir/
cp -a $tmpdir/packetfence/raddb $dst_dir/

mkdir -p $dst_dir/html/captive-portal/profile-templates/
touch $dst_dir/html/captive-portal/profile-templates/.empty

mkdir -p $dst_dir/fingerbank
cp -a $tmpdir/packetfence/addons/perl-client/conf  $dst_dir/fingerbank/
touch $dst_dir/fingerbank/conf/fingerbank.conf

find $dst_dir -name .gitignore -delete

chmod a+r -R $dst_dir
