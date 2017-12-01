#!/bin/bash

PF_DIR=/usr/local/pf

UPGRADED_DB="pf_upgraded_$$"

PRISTINE_DB="pf_pristine_$$"

MYSQL=$(printf "mysql -uroot -p%q" "$MYSQL_PASS")

MYSQLDUMP=$(printf "mysqldump -uroot --no-data -a --skip-comments -p%q" "$MYSQL_PASS")

LAST_SCHEMA=$(ls $PF_DIR/db/pf-schema-[0-9]*sql | sort --version-sort -r | head -1)

for db in $UPGRADED_DB $PRISTINE_DB;do
    echo "Created test db $db"
    mysql -uroot -p"$MYSQL_PASS" -e"DROP DATABASE IF EXISTS $db;"
    mysql -uroot -p"$MYSQL_PASS" -e"CREATE DATABASE $db;"
done

echo "Creating db of last schema $LAST_SCHEMA"

mysql -uroot -p"$MYSQL_PASS" $UPGRADED_DB < "$LAST_SCHEMA"

echo "Applying upgrade script $PF_DIR/db/upgrade-X.X.X-X.Y.Z.sql"

mysql -uroot -p"$MYSQL_PASS" $UPGRADED_DB < "$PF_DIR/db/upgrade-X.X.X-X.Y.Z.sql"

echo "Applying $PF_DIR/db/pf-schema-X.Y.Z.sql"

mysql -uroot -p"$MYSQL_PASS" $PRISTINE_DB < "$PF_DIR/db/pf-schema-X.Y.Z.sql"

for db in $UPGRADED_DB $PRISTINE_DB;do
    mysqldump -uroot --no-data -a --skip-comments -p"$MYSQL_PASS" $db > "${db}.dump"
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
    mysql -uroot -p"$MYSQL_PASS" -e"DROP DATABASE IF EXISTS $db;"
done
