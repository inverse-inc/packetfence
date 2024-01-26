#!/bin/bash

SERVICE=${1:-noservice}
STATUS=${2:-add}
ZONE=${3:-trusted}
PERMANENT=${4:-yes}
FIREWALLD_CMD_PATH=${5:-/usr/bin/firewall-cmd}

PERMANENT_VAL="--permanent"
FIREWALLD_DEFAULT_CONFIG_PF_PATH="/usr/local/pf/firewalld/services"
FIREWALLD_APPLIED_CONFIG_PF_PATH="/usr/local/pf/conf/firewalld/applied/services"

#
# Service part
#

if [[ "${STATUS}" != "add" ]] && [[ "${STATUS}" != "remove" ]] ;
then
  echo "Status ${STATUS} is unknown. should be 'add' or 'remove'";
  exit 1
fi

if ! [ -f ${FIREWALLD_DEFAULT_CONFIG_PF_PATH}/${SERVICE}.xml ];
then
  echo "Service ${SERVICE} Unavailable in configuration";
  echo "Check if ${SERVICE}.xml is in ${FIREWALLD_DEFAULT_CONFIG_PF_PATH}";
  exit 1;
fi

if [ ${PERMANENT} != "yes" ];
then
  PERMANENT_VAL=""
fi

printf "Service ${SERVICE} is in default config\n"
/bin/bash -c "cp ${FIREWALLD_DEFAULT_CONFIG_PF_PATH}/${SERVICE}.xml ${FIREWALLD_APPLIED_CONFIG_PF_PATH}/${SERVICE}.xml"
printf "Service ${SERVICE} is now in applied config\n"
/bin/bash -c "${FIREWALLD_CMD_PATH} --zone=${ZONE} --${STATUS}-service ${SERVICE} ${PERMANENT_VAL}"
echo "Service ${SERVICE} has been added to ${ZONE}"
/bin/bash -c "${FIREWALLD_CMD_PATH} --reload";
echo "Firewalld config reloaded";
exit

