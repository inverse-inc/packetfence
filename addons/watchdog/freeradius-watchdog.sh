#!/bin/bash
#
# FreeRADIUS watchdog
#
# Exist because, at some point, FreeRADIUS was locking and no longer
# replying to requests but the process was still alive.
#
# TODO this test should be migrated into `bin/pfcmd service ... watch`
#
# Copyright (C) 2005-2019 Inverse inc.
#
# Author: Inverse inc. <info@inverse.ca>
#
# Licensed under the GPL

# Variables
EMAILTO="user@domain.tld"
# if you want to add more recipients seperate them with a comma

# NOTE TO HIGH AVAILABILITY USERS
# Need to change SERVER_IP to the virtual IP and add a radius client in
# raddb/clients from the virtual IP with secret testing123
SERVER_IP=127.0.0.1

# setting separator to newline
IFS='
'
HOST=`hostname`

# function to test radius
function radius_test () {
    # looping on individual lines
    WORKING=0
    for OUTPUT in `radtest testuser testpass $SERVER_IP 12 testing123 2>&1`
    do
        if [[ "$OUTPUT" =~ ^"radclient: no response from server for" ]]; then
            WORKING=0
            break
        elif [[ "$OUTPUT" =~ ^"rad_recv: Access-Accept packet from host" ]]; then
            WORKING=1
        fi
    done
    return $WORKING;
}

# test run, if doesn't work
radius_test
if [[ $? == 0 ]]; then

    # try friendly stop, give 10 secs for shutdown then agressive kill
    /sbin/service radiusd stop && sleep 10 && pkill -9 radiusd
    /usr/local/pf/bin/pfcmd service radiusd start

    # re-test and report success or failure
    radius_test
    if [[ $? == 1 ]]; then
        MSG="Freeradius server is not responding on $HOST, restarting...\nSuccessfully restarted!"
    else
        MSG="Freeradius server is not responding on $HOST, restarting...\nEven after restart I can't query radius, you should diagnose the problem"
    fi

    echo -e $MSG
    MESSAGE=`tail -n 20 /var/log/radius/radius.log`
    echo -e "$MSG\r\nRadius Log Output:\r\n$MESSAGE" | /bin/mail -s "freeradius watchdog alert on $HOST!" "$EMAILTO"
fi

