#!/bin/bash
TEST_DIR=/usr/local/pf/t

if [ "$#" -ne "3" ];then
    echo "Number of args not valid"
    echo "Usage: $0 test_script BAD_COMMIT GOOD_COMMIT"
    exit 1
fi

TEST=$1

if [ ! -f "$TEST_DIR/$TEST" ];then
    echo $TEST does not exists
    exit 127
fi

BAD=$2
GOOD=$3

git bisect start "$BAD" "$GOOD"
git bisect run "$TEST_DIR/bisect-run.sh" "$TEST"
git bisect reset
