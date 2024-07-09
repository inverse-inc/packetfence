#!/bin/bash

#Test if stdout is a terminal
if [ -t 1 ]; then
    RED_COLOR=$(echo -en '\e[31m')
    RESET_COLOR=$(echo -en '\033[0m')
else
    RED_COLOR=
    RESET_COLOR=
fi


PF_DIR=/usr/local/pf

DB_PREFIX=pf_smoke_test_

UPGRADED_DB="${DB_PREFIX}_upgraded_$$"

PRISTINE_DB="${DB_PREFIX}_pristine_$$"

UPGRADE_ARGS='--init-command=SET SESSION innodb_strict_mode=OFF;';

HOST=localhost

MYSQL="mysql -upf_smoke_tester -ppacket -h$HOST"

MYSQLDUMP="mysqldump -upf_smoke_tester -h$HOST --no-data -a --skip-comments --routines -ppacket"

CURRENT_SCHEMA="$PF_DIR/db/pf-schema-X.Y.sql"
FIRST_SCHEMA="$PF_DIR/db/pf-schema-2.0.0.sql"

#if [ ! -e "$CURRENT_SCHEMA" ]; then
#    CURRENT_SCHEMA="$PF_DIR/db/pf-schema.sql"
#    if [ ! -f "$CURRENT_SCHEMA" ]; then
#        CURRENT_SCHEMA=$(ls $PF_DIR/db/pf-schema-[0-9]*sql | sort --version-sort -r | head -1 )
#    fi
#fi

for db in $UPGRADED_DB $PRISTINE_DB;do
    $MYSQL -e"DROP DATABASE IF EXISTS $db;"
    if [ $? != "0" ];then
        echo "Error dropping database $db"
        exit 1;
    fi
    $MYSQL -e"CREATE DATABASE $db;"
    if [ $? != "0" ];then
        echo "Error creating database $db"
        exit 1;
    fi
    echo "Created test db $db"
done

echo "Applying current schema $CURRENT_SCHEMA"

$MYSQL $PRISTINE_DB < "$CURRENT_SCHEMA"
if [ $? != "0" ];then
    echo "Error applying current schema $CURRENT_SCHEMA"
    exit 1;
fi

echo "Applying last schema $FIRST_SCHEMA"

$MYSQL "$UPGRADE_ARGS" $UPGRADED_DB < "$FIRST_SCHEMA"

for UPGRADE_SCRIPT in $(ls db/upgrade-[0-9]*.sql | sort --version-sort | grep -v 'upgrade-1\.' | grep -v 'upgrade-3.0.0-3.0.1.sql');do
    echo "Applying upgrade script $UPGRADE_SCRIPT"
    $MYSQL "$UPGRADE_ARGS" $UPGRADED_DB < "$UPGRADE_SCRIPT"
    if [ $? != "0" ];then
        echo "Error applying upgrade script $UPGRADE_SCRIPT"
        exit 1;
    fi
done

for db in $UPGRADED_DB $PRISTINE_DB;do
    $MYSQLDUMP $db > "${db}.dump"
done

#Ignore sort of indexes but ensure sort order of columns
if [ -n "$(diff -w <(sort "${PRISTINE_DB}.dump" | perl -pi -e's/,$//;s/AUTO_INCREMENT=\d+/AUTO_INCREMENT=0/')  <(sort "${UPGRADED_DB}.dump" | perl -pi -e's/,$//;s/AUTO_INCREMENT=\d+/AUTO_INCREMENT=0/'))" ] ||
    [ -n "$(diff -w <(perl -pi -e's/^\s*(KEY|CONSTRAINT).*$//;s/AUTO_INCREMENT=\d+/AUTO_INCREMENT=0/' < "${PRISTINE_DB}.dump")   <(perl -pi -e's/^\s*(KEY|CONSTRAINT).*$//;s/AUTO_INCREMENT=\d+/AUTO_INCREMENT=0/' <  "${UPGRADED_DB}.dump"))" ];then
    diff -uw "${PRISTINE_DB}.dump" "${UPGRADED_DB}.dump" > "${UPGRADED_DB}.diff"
    echo "${RED_COLOR}Upgrade did not create the same db"
    echo "Please look at ${UPGRADED_DB}.diff for the differences"
    echo "You can also look at ${PRISTINE_DB}.dump and ${UPGRADED_DB}.dump${RESET_COLOR}"
    exit 1
else
    echo "Upgrade is successful"
    rm -f "${PRISTINE_DB}".dump "${UPGRADED_DB}".dump
fi

for db in $UPGRADED_DB $PRISTINE_DB;do
    echo "Deleting test db $db"
    $MYSQL -e"DROP DATABASE IF EXISTS $db;"
done
