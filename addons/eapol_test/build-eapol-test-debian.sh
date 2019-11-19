#!/bin/bash
# source: https://wiki.freeradius.org/guide/eduroam#tooling_eapol_test
set -o nounset -o pipefail -o errexit

echo "Installing build dependencies.."
sudo apt-get install -y git libssl-dev devscripts pkg-config libnl-3-dev libnl-genl-3-dev

git clone --progress --depth 1 --no-single-branch \
    https://github.com/FreeRADIUS/freeradius-server.git ${HOME}/freeradius-server

echo "Building eapol_test.."
( cd ${HOME}/freeradius-server/scripts/travis/ \
      && ./eapol_test-build.sh \
      && cp ./eapol_test/eapol_test /usr/local/bin/ )
