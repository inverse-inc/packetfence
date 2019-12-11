#!/bin/bash
set -o nounset -o pipefail -o errexit

SRC_DIR=${SRC_DIR:-/src}
PF_DIR=${PF_DIR:-/usr/local/pf}
GO_DIR=${GO_DIR:-"$PF_DIR/go"}
PERL_TESTS=${PERL_TESTS:-yes}
GOLANG_TESTS=${GOLANG_TESTS:-yes}

# display environment
env | grep 'PF_'

# Copy 't' dir from sources to /usr/local/pf/t
# /usr/local/pf is hardcoded everywhere in 't'
cp -a ${SRC_DIR}/t ${PF_DIR}

# Preliminary steps before running unit tests
# used MYSQL_PWD env variable
mysql -uroot < ${PF_DIR}/t/db/smoke_test.sql;

if [ "$PERL_TESTS" = "yes" ]; then
    echo "Running Perl unit tests"

    # Makefile is always part of packetfence package
    # use for post-install tasks
    make -C ${PF_DIR} test
else
    echo "Perl unit tests disabled"
fi

if [ "$GOLANG_TESTS" = "yes" ]; then
    echo "Running Golang unit tests"
    make -C ${GO_DIR} test
else
    echo "Golang unit tests disabled"
fi
