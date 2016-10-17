#!/bin/bash
#fname:check-tmp.sh

MAX_TMP_FILES="${MAX_TMP_FILES:-"1000"}"

if [ `find /tmp/ -type f | wc -l` -gt 1000 ] ; then 
  echo "There are too much temp files in /tmp"
  exit 1
fi
