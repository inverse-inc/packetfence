#!/bin/bash

script_name=check-httpd.portal.sh

tmpfile=$(mktemp /tmp/check-httpd.portal.XXXXXX)

netstat -nlp | grep ':80 ' | awk '{ print $4 }' > $tmpfile

while read host; do
  echo "Testing $host"
  if ! curl -m 10 -I "$host/captive-portal" | head -n 1 | egrep "HTTP/1.1 (200|302)" ; then
    echo "$script_name Wrong return code for captive-portal on host $host"
    rm $tmpfile
    exit 1
  fi
done < $tmpfile

rm $tmpfile
