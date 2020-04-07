#!/bin/bash
set -o nounset -o pipefail -o errexit

SRC_DIR=${SRC_DIR:-/src}
PF_DIR=${PF_DIR:-/usr/local/pf}
GO_DIR=${GO_DIR:-"$PF_DIR/go"}
VENOM_DIR=${VENOM_DIR:-/usr/local/pf/t/venom}
PERL_UNIT_TESTS=${PERL_UNIT_TESTS:-no}
GOLANG_UNIT_TESTS=${GOLANG_UNIT_TESTS:-no}
INTEGRATION_TESTS=${INTEGRATION_TESTS:-no}

declare -p PERL_UNIT_TESTS GOLANG_UNIT_TESTS INTEGRATION_TESTS

### Common steps for all tests
# Copy 't' dir from sources to /usr/local/pf/t
# /usr/local/pf is hardcoded everywhere in 't'
cp -a ${SRC_DIR}/t ${PF_DIR}

# Preliminary steps before running Perl and Golang unit tests
# used MYSQL_PWD env variable
configure_smoke_db() {
    echo "Configure pf_smoke_test database"
    mysql -uroot < ${PF_DIR}/t/db/smoke_test.sql;
    ${PF_DIR}/t/db/setup_test_db.pl
}

if [ "$PERL_UNIT_TESTS" = "yes" ]; then
    configure_smoke_db
    echo "Running Perl unit tests"

    declare -p PF_TEST_MGMT_INT
    declare -p PF_TEST_MGMT_IP
    declare -p PF_TEST_MGMT_MASK
    # Makefile is always part of packetfence package
    # use for post-install tasks
    make -C ${PF_DIR} test
else
    echo "Perl unit tests disabled"
fi

if [ "$GOLANG_UNIT_TESTS" = "yes" ]; then
    configure_smoke_db
    echo "Running Golang unit tests"
    make -C ${GO_DIR} test
else
    echo "Golang unit tests disabled"
fi

if [ "$INTEGRATION_TESTS" = "yes" ]; then
    echo "Running integration tests"
    make -C ${VENOM_DIR} test
else
    echo "Integration tests disabled"
fi
