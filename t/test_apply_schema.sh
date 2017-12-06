#!/bin/bash

PF_DIR=/usr/local/pf

DB_PREFIX=pf_smoke_test_

UPGRADED_DB="${DB_PREFIX}_upgraded_$$"

PRISTINE_DB="${DB_PREFIX}_pristine_$$"

MYSQL="mysql -upf_smoke_tester -ppacket"

MYSQLDUMP="mysqldump -upf_smoke_tester --no-data -a --skip-comments -ppacket"

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

rm -f ${PRISTINE_DB}.dump ${UPGRADED_DB}.dump

if [ -z "$DIFF" ];then
    echo "Upgrade is successful"
    rm -f upgrade.diff
else
    echo "Upgrade did not create the same db"
    echo "Please look at upgrade.diff for the differences"
fi

for db in $UPGRADED_DB $PRISTINE_DB;do
    echo "Deleting test db $db"
    $MYSQL -e"DROP DATABASE IF EXISTS $db;"
done
