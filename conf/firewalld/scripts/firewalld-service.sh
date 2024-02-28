#!/bin/bash

SERVICE=${1:-noservice}
STATUS=${2:-add}
ZONE=${3:-eth0}
PERMANENT=${4:-yes}
FIREWALLD_CMD_PATH=${5:-/usr/bin/firewall-cmd}

PERMANENT_VAL="--permanent"
FIREWALLD_DEFAULT_CONFIG_PF_PATH="/usr/local/pf/firewalld/services"
FIREWALLD_APPLIED_CONFIG_PF_PATH="/usr/local/pf/var/firewalld/services"

#
# Service part
#

if [[ "${STATUS}" != "add" ]] && [[ "${STATUS}" != "remove" ]] ;
then
  echo "Status ${STATUS} is unknown. should be 'add' or 'remove'";
  exit 1
fi

if [ ${PERMANENT} != "yes" ];
then
  PERMANENT_VAL=""
fi

# handle service's file
if [[ "${STATUS}" == "add" ]];
then
  if ! [ -f ${FIREWALLD_DEFAULT_CONFIG_PF_PATH}/${SERVICE}.xml ];
  then
    echo "Service ${SERVICE} Unavailable in configuration";
    echo "Check if ${SERVICE}.xml is in ${FIREWALLD_DEFAULT_CONFIG_PF_PATH}";
    exit 1;
  fi
  printf "Service ${SERVICE} is ${STATUS}ed in Firewalld applied configuration.\n"
  /bin/bash -c "cp ${FIREWALLD_DEFAULT_CONFIG_PF_PATH}/${SERVICE}.xml ${FIREWALLD_APPLIED_CONFIG_PF_PATH}/${SERVICE}.xml"
else
  printf "Service ${SERVICE} is ${STATUS}ed from Firewalld applied configuration.\n"
  /bin/bash -c "rm -rf ${FIREWALLD_APPLIED_CONFIG_PF_PATH}/${SERVICE}.xml*"
fi

# handle service in zone
if [[ "${STATUS}" == "add" ]];
then
  echo "Service ${SERVICE} ${STATUS}ed from Zone ${ZONE} configuration status:"
else
  echo "Service ${SERVICE} ${STATUS}d from Zone ${ZONE} configuration status:"
fi
/bin/bash -c "${FIREWALLD_CMD_PATH} --zone=${ZONE} --${STATUS}-service ${SERVICE} ${PERMANENT_VAL}"

# handle status
echo "Firewalld config status:";
/bin/bash -c "${FIREWALLD_CMD_PATH} --reload";

exit
