#!/bin/bash
# lmunro@inverse.ca 20130508
# License: GNU General Public License 2 (GPL2)
#
# This script is called from heartbeat (or corosync) to manage 
# the Barnyard2 resource.
# It is loosely based on the barnyard2 init script.

# Source function library
. /etc/rc.d/init.d/functions

# program name
BASE=barnyard2

# program options
CONF="/usr/local/$BASE/etc/barnyard2.conf"
GEN_MAP="/usr/local/pf/conf/snort/gen-msg.map"
SID_MAP="/usr/local/pf/conf/snort/sid-msg.map"
LOG_DIR="/var/log/snort"
SPOOL_DIR="/var/log/snort"
LOG_FILE="merged.log"
WALDO_FILE="/var/log/snort/barnyard2.waldo"
DAEMON="-D"

# Check that $BASE exists.
[ -f /usr/local/bin/$BASE ] || exit 0

# source ocf functions
: ${OCF_FUNCTIONS_DIR=${OCF_ROOT}/resource.d/heartbeat}
. ${OCF_FUNCTIONS_DIR}/.ocf-shellfuncs


RETVAL=0


_get_meta_data() {
        cat <<END
<?xml version="1.0"?>
<!DOCTYPE resource-agent SYSTEM "ra-api-1.dtd">
<resource-agent name="Barnyard">
<version>1.0</version>
        
<longdesc lang="en"> 
The Barnyard resource agent manages the barnyard2 service.
</longdesc>
                
<shortdesc lang="en">
Barnyard
</shortdesc>    

<parameters>
</parameters>   

<actions>
<action name="start"   timeout="300" />
<action name="stop"    timeout="100" />
<action name="monitor" depth="0"  timeout="20" interval="20" />
<action name="meta-data"  timeout="5" />
</actions>
</resource-agent>
END
        
        return $OCF_SUCCESS
}



_start () {
    if [ -n "`/sbin/pidof $BASE`" ]; then
      echo -n $"$BASE: already running"
      echo ""
      exit $OCF_SUCCESS
    fi
    echo -n "Starting Barnyard: "
    /usr/local/bin/$BASE -c $CONF -G $GEN_MAP -S $SID_MAP -d $SPOOL_DIR -l $LOG_DIR -f $LOG_FILE -w $WALDO_FILE $DAEMON
    sleep 1
    action "" /sbin/pidof $BASE
    RETVAL=$?
    [ $RETVAL -eq 0 ] && touch /var/lock/subsys/barnyard2
}

_stop () {
    echo -n "Shutting down Barnyard: "
    killproc /usr/local/bin/$BASE
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && rm -f /var/lock/subsys/barnyard2
}

_monitor () {
    status $BASE || RETVAL=7
}

_usage () {
    echo "Usage: barnyard {start|stop|monitor|meta_data}"
}

case $__OCF_ACTION in
	meta-data) 
		    _get_meta_data
		exit $OCF_SUCCESS
		;;
        start)      _start
	        exit $RETVAL
                ;;
        stop)       _stop
                ;;
        monitor)    _monitor
	        exit $RETVAL
                ;;
        *)          _usage
                exit $OCF_ERR_UNIMPLEMENTED
	        ;;
esac

exit $?
