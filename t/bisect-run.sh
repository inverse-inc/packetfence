#!/bin/bash
TEST_DIR=/usr/local/pf/t
if [ -f /usr/local/pf/var/run/pfconfig-test.pid ];then
    kill $(cat /usr/local/pf/var/run/pfconfig-test.pid)
    sleep 1
fi

cd $TEST_DIR
perl "$1"
exit $?
