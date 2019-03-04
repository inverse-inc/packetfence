#!/bin/bash
#
# Config comparator
# 
# - This will compare the generated configuration in different modules in two different branches.
# - Note that the pfconfig data that is seen is the one running in the service
#
# Copyright (C) 2005-2019 Inverse inc.
#
# Author: Inverse inc. <info@inverse.ca>
#
# Licensed under the GPL
#

LE_DIR='/tmp/config-comparator'

BRANCH_1=$1
BRANCH_2=$2

if [ -z "$BRANCH_1" ] || [ -z "$BRANCH_2" ]; then
  echo "Missing branch names : "
  echo "Usage : config-comparator <branch1> <branch2>"
  exit 1
fi;

mkdir -p $LE_DIR
rm -fr $LE_DIR/*

cd $LE_DIR

git clone https://github.com/inverse-inc/packetfence.git
cp -frp packetfence packetfenceb1
cp -frp packetfence packetfenceb2

cd $LE_DIR/packetfenceb1 && git checkout $BRANCH_1
if [ $? -ne 0 ]; then
  echo "Failed to checkout $BRANCH_1"
  exit 5
fi

cd $LE_DIR/packetfenceb2 && git checkout $BRANCH_2
if [ $? -ne 0 ]; then 
  echo "Failed to checkout $BRANCH_2"
  exit 5
fi

cd $LE_DIR

cp -frp /usr/local/pf/addons/pfconfig/comparator/dumper.pl .
cp -frp /usr/local/pf/addons/pfconfig/comparator/comparator.pl .

service packetfence-config restart
/usr/local/pf/bin/pfcmd configreload hard

perl dumper.pl "$LE_DIR/packetfenceb1/lib" packetfenceb1
perl dumper.pl "$LE_DIR/packetfenceb2/lib" packetfenceb2

perl comparator.pl "$LE_DIR/packetfenceb1.out" "$LE_DIR/packetfenceb2.out"
