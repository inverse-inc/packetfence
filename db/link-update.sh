#!/bin/bash
#
cd /usr/local/pf/db

TARGET=pf-schema-X.Y.sql

if [ ! -e "$TARGET" ];then
    TARGET=$(ls pf-schema-* | sort -V -r | head -1)
fi

ln -f -s $TARGET pf-schema.sql
