#!/bin/bash

INTERFACE=${1:-eth0}
ZONE=${2:-external}
MASQUERADE=${3:-yes}
FIREWALLD_CMD_PATH=${4:-/usr/bin/firewall-cmd}
PERMANENT=${5:-yes}

PERMANENT_VAL="--permanent"

#
# Docker Interface
#

AVAILABLE_ZONE=$(/bin/bash -c "${FIREWALLD_CMD_PATH} --get-zones | tr -s '[:blank:]' '\n' | grep '^${ZONE}$'")
if [ -z ${AVAILABLE_ZONE} ];
then
  echo "Zone (${ZONE}) Does not exist";
  exit 1
fi

if [[ ${PERMANENT} != "yes" ]];
then
  PERMANENT_VAL=""
fi

/bin/bash -c "${FIREWALLD_CMD_PATH} ${PERMANENT_VAL} --zone=${ZONE} --add-interface=${INTERFACE}";
echo "Add Zone (${ZONE}) to Interface ${INTERFACE} Permanently";

if [ ${MASQUERADE} == "yes" ];
then
  /bin/bash -c "${FIREWALLD_CMD_PATH} --zone=${ZONE} --add-masquerade ${PERMANENT_VAL}";
  echo "Add Masquerade Permanent to ${ZONE}";
else
  /bin/bash -c "${FIREWALLD_CMD_PATH} --zone=${ZONE} --remove-masquerade ${PERMANENT_VAL}";
  echo "Remove Masquerade Permanent for Zone ${ZONE}";
fi

/bin/bash -c "${FIREWALLD_CMD_PATH} --reload";
echo "Firewalld config reloaded";
exit
