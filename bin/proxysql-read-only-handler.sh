#!/bin/bash

PROXYSQL_CONF="${1}"
MYSQL_CONF="${2}"
QUERY_CONF="${3}"
ERR_FILE="${4}"

: > $ERR_FILE

PROXYSQL_USERNAME=`echo "$PROXYSQL_CONF" | jq -r .username`
PROXYSQL_PASSWORD=`echo "$PROXYSQL_CONF" | jq -r .password`
PROXYSQL_HOST=`echo "$PROXYSQL_CONF" | jq -r .host`
PROXYSQL_PORT=`echo "$PROXYSQL_CONF" | jq -r .port`
#echo "$PROXYSQL_USERNAME $PROXYSQL_PASSWORD $PROXYSQL_HOST $PROXYSQL_PORT"

MYSQL_USERNAME=`echo "$MYSQL_CONF" | jq -r .username`
MYSQL_PASSWORD=`echo "$MYSQL_CONF" | jq -r .password`
#echo "$MYSQL_USERNAME $MYSQL_PASSWORD"

READ_WRITE_HOSTGROUP=`echo "$QUERY_CONF" | jq -r .read_write_hostgroup`
READ_HOSTGROUP=`echo "$QUERY_CONF" | jq -r .read_hostgroup`
QUERY_RULE_IDS=`echo "$QUERY_CONF" | jq -r .rule_ids`
#echo "$READ_WRITE_HOSTGROUP $READ_HOSTGROUP $QUERY_RULE_IDS"

TIMEOUT=10

PROXYSQL_CMDLINE="mysql -u$PROXYSQL_USERNAME -p$PROXYSQL_PASSWORD -h $PROXYSQL_HOST -P $PROXYSQL_PORT -Ne"
MYSQL_CMDLINE="timeout $TIMEOUT mysql -nNE -u$MYSQL_USERNAME -p$MYSQL_PASSWORD "

HAS_ONE_READY=no
HAS_ONE_READ_WRITE=no
while read server port stat
do
  WSREP_READY=$($MYSQL_CMDLINE -h $server -P $port -e "SHOW STATUS LIKE 'wsrep_ready'" 2>>${ERR_FILE} | tail -1 2>>${ERR_FILE})
  if [ "${WSREP_READY}" = "ON" ] ; then
    echo `date` SERVER $server:$port is WSREP_READY=ON >> ${ERR_FILE}
    HAS_ONE_READY=yes
  fi
  READ_ONLY=$($MYSQL_CMDLINE -h $server -P $port -e "SELECT @@global.read_only;" 2>>${ERR_FILE} | tail -1 2>>${ERR_FILE})
  if [ "${READ_ONLY}" = "0" ] ; then
    echo `date` SERVER $server:$port is READ_ONLY=0 >> ${ERR_FILE}
    HAS_ONE_READ_WRITE=yes
  fi
done <<< "$($PROXYSQL_CMDLINE "SELECT hostname,port,status FROM mysql_servers WHERE hostgroup_id='$READ_WRITE_HOSTGROUP'")"

#echo "$HAS_ONE_READY $HAS_ONE_READ_WRITE"

if [ "${HAS_ONE_READY}" = "no" ] || [ "${HAS_ONE_READ_WRITE}" = "no" ]; then
  echo `date` All the servers have either wsrep_ready=off or read_only=1, stopping writes >> ${ERR_FILE}
  DESTINATION_HOSTGROUP=$READ_HOSTGROUP
  REPLACE_PATTERN="'ERROR DB IS IN R/O'"
else
  echo `date` At least one server has wsrep_ready=on and read_only=0 >> ${ERR_FILE}
  DESTINATION_HOSTGROUP=$READ_WRITE_HOSTGROUP
  REPLACE_PATTERN="NULL"
fi

# Only update and load the query rules when some of them are not in the expected state, ProxySQL logs every load.
# There are no such rules when the cluster has no read hostgroup.
RULE_STATE="rule_id IN ($QUERY_RULE_IDS) AND NOT (destination_hostgroup IS $DESTINATION_HOSTGROUP AND replace_pattern IS $REPLACE_PATTERN)"
RULES_TO_CHANGE=$($PROXYSQL_CMDLINE "SELECT (SELECT COUNT(*) FROM mysql_query_rules WHERE $RULE_STATE) + (SELECT COUNT(*) FROM runtime_mysql_query_rules WHERE $RULE_STATE)" 2>> ${ERR_FILE})
if [ "${RULES_TO_CHANGE}" = "0" ]; then
  echo `date` Query rules already route to hostgroup $DESTINATION_HOSTGROUP >> ${ERR_FILE}
else
  echo `date` Routing the query rules to hostgroup $DESTINATION_HOSTGROUP >> ${ERR_FILE}
  $PROXYSQL_CMDLINE "update mysql_query_rules set replace_pattern=$REPLACE_PATTERN, destination_hostgroup=$DESTINATION_HOSTGROUP where rule_id IN ($QUERY_RULE_IDS); LOAD MYSQL QUERY RULES TO RUNTIME;" 2>> ${ERR_FILE}
fi
