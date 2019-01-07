#!/bin/bash
PF_DIR="/usr/local/pf"
find "$PF_DIR/html/captive-portal/profile-templates" "$PF_DIR/conf" -type f -print0 | while read -d $'\0' file; do
    if file --mime-encoding  "$file" | grep -q iso-8859-1  ;then
        echo "converting $file from iso-8859-1 to utf-8" 
        iconv --from-code=iso-8859-1 --to-code=utf-8 "$file" -o "$file"
   fi
done
echo "Finished converting files"
