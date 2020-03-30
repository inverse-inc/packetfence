#!/bin/bash
tmpfile=$(mktemp /tmp/generator-radius-attributes.XXXXXX)
PF_DIR=/usr/local/pf
DEV_HELP="$PF_DIR/addons/dev-helpers"
go run $DEV_HELP/bin/generator-radius-attributes.go | json_xs -tdump > $tmpfile

tpage --absolute --define "dump=$tmpfile" --define "year=$(date +"%Y")" \
    --include_path="${DEV_HELP}/templates" "${DEV_HELP}/templates/pf-util-radius_dictionary.pm.tt" \
    | perltidy > "$PF_DIR/lib/pf/util/radius_dictionary.pm"

rm -rf $tmpfile
