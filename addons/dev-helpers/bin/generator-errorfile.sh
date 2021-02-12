#!/bin/bash
PF_DIR=/usr/local/pf
JSON_DIR="$PF_DIR/html/pfappserver/root/static"

for f in $(ls $JSON_DIR/[0-9][0-9][0-9].json);do
    n=$(basename $f .json)
    cat <<ERR > "$JSON_DIR/${n}.json.http"
HTTP/1.1 $n $(jq -r .message < $f)
Content-Type: application/json
Content-Length: $(stat $f -c "%s")

$(cat $f)
ERR

done
