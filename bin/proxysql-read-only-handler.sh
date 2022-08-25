#!/bin/bash

set -o nounset -o pipefail -o errexit

PROXYSQL_CONF="${1}"
MYSQL_CONF="${2}"
QUERY_CONF="${3}"
ERR_FILE="${4}"

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
  echo `date` All the servers are either wsrep_ready=off or read_only=1, stopping writes >> ${ERR_FILE}
  $PROXYSQL_CMDLINE "update mysql_query_rules set replace_pattern='ERROR DB IS IN R/O', destination_hostgroup=$READ_HOSTGROUP where rule_id IN ($QUERY_RULE_IDS); LOAD MYSQL QUERY RULES TO RUNTIME;" 2>> ${ERR_FILE}
else
  echo `date` At least one server is wsrep_ready=on and read_only=0 >> ${ERR_FILE}
  $PROXYSQL_CMDLINE "update mysql_query_rules set replace_pattern=NULL, destination_hostgroup=$READ_WRITE_HOSTGROUP where rule_id IN ($QUERY_RULE_IDS); LOAD MYSQL QUERY RULES TO RUNTIME;" 2>> ${ERR_FILE}
fi
