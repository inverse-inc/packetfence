#!/bin/bash

script_dir="/usr/local/pf/var/monitoring-scripts/"
full_output=""
mailto="jsemaan@inverse.ca"

ERROR=0

function _run {
  cmd="$1"

  output=`$cmd`
  if [ $? -eq 0 ]; then
    echo "$cmd succeeded" > /dev/null
  else
    ERROR=1
    echo "$cmd failed" > /dev/null
    output="Result of $cmd\n$output"
    output="$output\n------------------------------------------"
    full_output="$full_output\n$output"
  fi
}

for f in $(find $script_dir -type f); do
  _run $f
done

if [ $ERROR -ne 0 ]; then
  echo -e $full_output
  exit 1
else
  exit 0
fi

