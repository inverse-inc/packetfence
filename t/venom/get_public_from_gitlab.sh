#!/bin/bash
set -o nounset -o pipefail

REPO_URL=https://gitlab.com/inverse-inc/packetfence/-/jobs?page=
MAXPAGE=5
ZIPFILE="./public.zip"
JOBID=""

if [ ! type curl 2> /dev/null ] ; then
  echo "Install curl before running this script"
  exit 0 
fi

if [ ! type wget 2> /dev/null ] ; then
  echo "Install wget before running this script"
  exit 0 
fi

# Check accross the first ${MAXPAGE} pages
WEXIT=0
i=0
while [ ${i} -le ${MAXPAGE} -a ${WEXIT} -lt 1 ]
do
  GITVAL=$(curl -s ${REPO_URL}${i})
  JOBIDS=($(echo ${GITVAL} | grep -oP '(?<=publish).*?(?=artifacts/download">)' | grep -oP '(?<=jobs/).*' | grep -oP '.*(?=\/)'))
  j=0
  if [ ${#JOBIDS[@]} -gt "1" ] ; then
    # Check if value is in the page
    while [ ${j} -lt ${#JOBIDS[@]} -a ${WEXIT} -lt 1 ]
    do
      JOBID=${JOBIDS[${j}]}
      # Check if jobid has at least 7 digits
      # If publish is cancelled, previous parsing generates lots of false values in JOBIDs.
      # It has already more than 7 digit and it goes up anyway...
      if [[ ${JOBID} != $(echo ${JOBID} | grep -oP '\d{6}\d+') ]]; then
        JOBID=""
      fi 
      # Check if jobid is not empty
      # First found is the latest
      if [[ ${JOBID} != "" ]]; then
        WEXIT=1
      fi
      j=$(( ${j} + 1 ))
    done
    i=$(( ${i} + 1 ))
  fi
done

# Download the archive zipfile, extract and remove
if [ -n ${JOBID} ]; then
  echo "The job id is ${JOBID}"
  wget -q https://gitlab.com/inverse-inc/packetfence/-/jobs/${JOBID}/artifacts/download?file_type=archive -O ${ZIPFILE}
  if [ -f ${ZIPFILE} ]; then
    echo "Public zipfile is there"
    unzip -oq ${ZIPFILE} -d ../../
    echo "Unzip is done"
    rm -f ${ZIPFILE}
    echo "Zipfile is removed"
    exit 0
  else
    echo "The zipfile is no available"
    exit 1
  fi
else
  echo "Sorry I haven't found any job id in the first ${MAXPAGE} pages"
fi
