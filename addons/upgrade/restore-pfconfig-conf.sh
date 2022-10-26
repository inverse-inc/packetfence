#!/bin/bash

set -o nounset -o pipefail -o errexit

mv -f -v /usr/local/pf/conf/pfconfig.conf.rpmsave /usr/local/pf/conf/pfconfig.conf
/bin/systemctl restart packetfence-config
