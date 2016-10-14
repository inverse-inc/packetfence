#!/bin/bash
#fname:check-tmp.sh

if [ `find /tmp/ -type f | wc -l` -gt 1000 ] ; then 
  echo "There are too much temp files in /tmp"
  exit 1
fi
