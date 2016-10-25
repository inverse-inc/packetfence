#!/bin/bash

DIR="$1"

if [ -z "$DIR" ]; then
  echo "You need to specify a directory"
  exit 255
fi

find $DIR -type f ! -name '*.sig' -exec gpg -u 0xE3A28334 --batch --yes --output {}.sig --sign {} \;

