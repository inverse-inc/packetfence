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

MYSQL="mysql -upf_smoke_tester -ppacket -h127.0.0.1"

MYSQLDUMP="mysqldump -upf_smoke_tester -h127.0.0.1 --no-data -a --skip-comments --routines -ppacket"

if ! [ -f "$PF_DIR/db/upgrade-X.X.X-X.Y.Z.sql" ]; then
  echo "X.X.X to X.Y.Z upgrade script doesn't exist. Not testing schema upgrade"
  exit 0
fi

for db in $UPGRADED_DB $PRISTINE_DB;do
    echo "Created test db $db"
    $MYSQL -e"DROP DATABASE IF EXISTS $db;"
    $MYSQL -e"CREATE DATABASE $db;"
done

LAST_SCHEMA=$(ls $PF_DIR/db/pf-schema-[0-9]*sql | sort --version-sort -r | head -1)

echo "Creating db of last schema $LAST_SCHEMA"

$MYSQL $UPGRADED_DB < "$LAST_SCHEMA"

echo "Applying upgrade script $PF_DIR/db/upgrade-X.X.X-X.Y.Z.sql"

$MYSQL $UPGRADED_DB < "$PF_DIR/db/upgrade-X.X.X-X.Y.Z.sql"

echo "Applying $PF_DIR/db/pf-schema-X.Y.Z.sql"

$MYSQL $PRISTINE_DB < "$PF_DIR/db/pf-schema-X.Y.Z.sql"

for db in $UPGRADED_DB $PRISTINE_DB;do
    $MYSQLDUMP $db > "${db}.dump"
done

DIFF=$(diff "${PRISTINE_DB}.dump" "${UPGRADED_DB}.dump" | tee upgrade.diff )

if [ -z "$DIFF" ];then
    echo "Upgrade is successful"
    rm -f upgrade.diff ${PRISTINE_DB}.dump ${UPGRADED_DB}.dump
else
    echo "${RED_COLOR}Upgrade did not create the same db"
    echo "Please look at upgrade.diff for the differences"
    echo "You can also look at ${PRISTINE_DB}.dump and ${UPGRADED_DB}.dump${RESET_COLOR}"
    exit 1
fi

for db in $UPGRADED_DB $PRISTINE_DB;do
    echo "Deleting test db $db"
    $MYSQL -e"DROP DATABASE IF EXISTS $db;"
done
