#!/bin/bash
#
# Slowly migrate content of locationlog to locationlog_archive
#
# Only useful if your locationlog is too big and you want to slowly move it 
# into locationlog_archive and you do not want to do it in one batch like the 
# database-backup-and-maintenance script would do
#
# It will proceed day by day starting by the older entries first and sleeping 
# for 5 minutes between each batch.
#
# Usage: migrate-to-locationlog_archive.sh <days>
# Where <days> is the number of days to migrate the records of.
#
# Copyright (C) 2005-2019 Inverse inc.
#
# Author: Inverse inc. <info@inverse.ca>
#
# Licensed under the GPL
#
DB_USER='pf';
# make sure access to this file is properly secured (chmod a=,u=rw) or that 
# you remove the password when you are done
DB_PASS='';
DB_NAME='pf';


if [[ -n "$1" ]]; then
  echo "Fetching earliest locationlog date from database"
  # what is the last not null and non-empty date
  EARLIEST=`/usr/bin/mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "select end_time from locationlog where (end_time IS NOT NULL OR end_time <> 0) order by end_time limit 1"`
  
  # if last command failed, quit
  if [[ $? -ne 0 ]]; then
    echo "last operation failed"
    exit 127
  fi

  EARLIEST=`echo $EARLIEST | awk '{print $2}'`

  # move day by day (from last day) the content of locationlog for the number of iterations specified on CLI
  for ((I=1; I<=$1; I++)); do
    /usr/bin/mysql -u $DB_USER -p$DB_PASS $DB_NAME -vvv -e "INSERT INTO locationlog_archive select * from locationlog where ((end_time IS NOT NULL OR end_time <> 0) and end_time < adddate(\"$EARLIEST\",$I))"
    /usr/bin/mysql -u $DB_USER -p$DB_PASS $DB_NAME -vvv -e "delete from locationlog where ((end_time IS NOT NULL OR end_time <> 0) and end_time < adddate(\"$EARLIEST\",$I))"
    echo "Sleeping for 5 minutes. Zzz"
    sleep 300
  done
else
  echo "You must specify a number of days to run the operation"
fi
