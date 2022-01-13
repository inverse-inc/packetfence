#!/bin/bash

source /usr/local/pf/addons/monit/monitoring-scripts/setup.sh

setup_test_env

full_output="Report for $uuid\n"

ERROR=0

function _run {
  cmd="$1"

  if is_ignored $cmd ; then
    echo "Ignoring $cmd because its part of the ignore list."
    return 0
  fi

  RUN_ROOT_SCRIPTS="${RUN_ROOT_SCRIPTS:-"1000"}"
  if [ "$RUN_ROOT_SCRIPTS" -ne 1 ] && grep -o --quiet '^#as-root$' $cmd ; then
    echo "Ignoring script $cmd because it has to run as root but it is denied on this setup."
    return
  elif grep -o --quiet '^#as-root$' $cmd; then
    echo "Running $cmd as root"
    cmd_output=`timeout 10 $cmd`
  else
    cmd_output=`timeout 10 su pf-monitoring -c $cmd`
  fi
  code="$?"

  if [ $code -eq 0 ]; then
    echo "$cmd succeeded" > /dev/null
  else
    ERROR=1
    if [ $code -eq 124 ]; then
      output="$cmd has timeout"
    else
      output="$cmd has failed"
    fi
    output="$output\nOutput of $cmd"
    output="$output\n$cmd_output\n------------------------------------------"
    full_output="$full_output\n$output"
  fi
}

for f in $(find $script_dir -type f); do
  _run $f
done

echo -e $full_output
if [ $ERROR -ne 0 ]; then
  exit 1
else
  echo "No error to report"
  exit 0
fi

