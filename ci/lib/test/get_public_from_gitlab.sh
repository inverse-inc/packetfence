#!/bin/bash
set -o nounset -o pipefail

REPO_URL=https://gitlab.com/inverse-inc/packetfence/-/jobs/artifacts/devel/download?job=pages
ZIP_FILE=$(mktemp --suff=".zip")

# get path to script directory
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# remove ci/lib/test from SCRIPT_DIR
RESULT_DIR=$(echo ${SCRIPT_DIR} | grep -oP '.*?(?=\/ci\/)')

echo "The directory used will be ${RESULT_DIR}"

# test if public is already there
if [ -d "${RESULT_DIR}/public/" ]; then
  echo "The public directory is already there. The script will stop."
  exit 0
fi

# test if curl installed
if ! type curl 2> /dev/null ; then
  echo "Install curl before running this script"
  exit 1 
fi

# Download the archive zipfile, extract and remove
curl -Ls ${REPO_URL} --output ${ZIP_FILE}
if [ -f ${ZIP_FILE} ]; then
  echo "Public zipfile is there ${ZIP_FILE}"
  unzip -oq ${ZIP_FILE} -d ${RESULT_DIR}
  echo "Unzip is done in ${RESULT_DIR}"
  rm -f ${ZIP_FILE}
  echo "Zipfile ${ZIP_FILE} is removed"
  exit 0
else
  echo "The zipfile is no available"
  exit 1
fi
