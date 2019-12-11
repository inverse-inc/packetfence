#!/bin/bash
set -o nounset -o pipefail -o errexit

SRC_DIR=${SRC_DIR:-/src}
PF_DIR=${PF_DIR:-/usr/local/pf}

# display environment
env | grep 'PF_'

# Copy 't' dir from sources to /usr/local/pf/t
# /usr/local/pf is hardcoded everywhere in 't'
cp -a ${SRC_DIR}/t ${PF_DIR}

# Preliminary steps before running unit tests
# use MYSQL_PWD env variable
mysql -uroot < ${PF_DIR}/t/db/smoke_test.sql;

# Makefile is always part of packetfence package
# use for post-install tasks
make -C ${PF_DIR} test
