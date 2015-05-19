#!/bin/bash

#This is will attempt to install all the packages
#from the spec file using just packetfence-devel repo
#

PFDIR=/usr/local/pf
SPEC="$PFDIR/addons/packages/packetfence.spec"
PF_REPO="--enablerepo=packetfence-devel"
STD_REPOS="--enablerepo=base --enablerepo=updates --enablerepo=extras"
YUM="yum --disablerepo=* $PF_REPO $STD_REPOS"
$YUM makecache

REPOQUERY="repoquery --queryformat=%{NAME} --disablerepo=* $PF_REPO $STD_REPOS -C --pkgnarrow=all"

TEMPFILE="/tmp/$$.$RANDOM"

rpm -q --requires --specfile $SPEC | grep -v packetfence \
    | perl -pi -e's/ +$//' | sort -u \
    | while read i
        do
            COUNT=$( $REPOQUERY --whatprovides "$i" | sort -u | tee $TEMPFILE | wc -l)
            if [ $COUNT = 0 ];then
                echo "No package found that provides '$i'"
            elif [ $COUNT != 1 ];then
                echo "Too many packages provide '$i' : $(cat $TEMPFILE | tr '\n' ' ')"
            fi
        done 

rm -f $TEMPFILE
