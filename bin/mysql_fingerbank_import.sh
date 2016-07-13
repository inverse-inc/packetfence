#!/bin/bash

function runit {
  cd /usr/local/fingerbank/
  result=`make init-mysql 2>&1`
  local status=$?
  if [ $status -ne 0 ]; then
    perl -I/usr/local/pf/lib -Mpf::config::util -e "pfmailer(subject => 'Failed to import Fingerbank data inside MySQL', message => qq[Output of the command was : $result])"
  else
    perl -I/usr/local/pf/lib -Mpf::config::util -e "pfmailer(subject => 'Successfully imported the Fingerbank data inside MySQL')"
  fi
}

runit
exit 0

