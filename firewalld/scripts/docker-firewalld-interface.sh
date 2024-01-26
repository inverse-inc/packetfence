#!/bin/bash

INTERFACE=${1:-docker0}
ZONE=${2:-trusted}

/bin/bash -c "/usr/local/pf/firewalld/scripts/firewalld-interface.sh ${INTERFACE} ${ZONE}"
