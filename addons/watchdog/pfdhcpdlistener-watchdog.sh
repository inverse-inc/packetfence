#!/bin/bash
#
# Copyright (C) 2005-2019 Inverse inc.
#
# Author: Inverse inc. <info@inverse.ca>
#
# Licensed under the GPL

# Variables
EMAILTO="user@domain.tld"
# if you want to add more recipients seperate them with a comma

HOST=`hostname`

# Let's make sure the folder exists... 

function test_folder_if_exist () {
        if [ -d /usr/local/pf/var/run ] ; then
                #echo "Good ! the folder exist"
		echo 1 > /dev/null
        else
                echo " /usr/local/pf/var/run folder doesn't exist"
                exit 1
        fi
}

function test_if_pfdhcpdlistener () {
	am_i_running=`/usr/local/pf/bin//pfcmd service pfdhcplistener status | awk -F "|" '{  print $2 }' | tail -1`
	if [ $am_i_running != 1 ] ; then
		## enable for debugging: 
		# echo "pfdhcpdlistener is not running or not started..."
		MESSAGE=`tail -n 20 /usr/local/pf/logs/packetfence.log`
		echo -e "$MSG\r\nPacketFence dhcplistener error on $HOST, please, investigate:\r\n" | /bin/mail -s "dhcpdlistener watchdog alert on $HOST!" "$EMAILTO"
		exit 1
	else
		## enable for debugging:
		##echo "pfdhcpdlistener is running, continuing..."
		echo 1> /dev/null
	fi
}

function validate_pid () {
	WORKING=0
        for file in /usr/local/pf/var/run/pfdhcplistener_* ; do
                 filename=`echo $file | awk -F "_" '{ print $2 }' | tr '.pid' ' '`  
		 pid=`cat $file`
	#echo "dhcplistener on interface: $filename Process ID: $pid"

        if ps -p $pid >&- ; then
                #echo " OK - is running "
		echo 1 > /dev/null
        else
                #echo " ERROR - is not running"
		WORKING=1
        fi

done
return $WORKING;
}
test_folder_if_exist
test_if_pfdhcpdlistener
validate_pid
if [[ $? != 0 ]]; then
	# let's try to restart pfdhcplistener 
	/usr/local/pf/bin/pfcmd service pfdhcplistener restart
	sleep 3
	# let's re-test and report success or failure... 
	validate_pid
	if [[ $? == 0 ]]; then
        MSG="pfdhcplistener server is not responding on $HOST, restarting...\nRestart completed !"
	MESSAGE=`/usr/local/pf/bin//pfcmd service pfdhcplistener status`
    	else
		MSG="pfdhcplistener is not responding on $HOST, and can't be restarted - please, investigate...\n"
		MESSAGE=`tail -n 20 /usr/local/pf/logs/packetfence.log`
    	fi

	#echo -e $MSG
	#echo  $MESSAGE
	echo -e "$MSG\r\nPacketFence Output:\r\n$MESSAGE" | /bin/mail -s "dhcpdlistener watchdog alert on $HOST!" "$EMAILTO"
fi

