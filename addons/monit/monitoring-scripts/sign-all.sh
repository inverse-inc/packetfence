#!/bin/bash

DIR="$1"

if [ -z "$DIR" ]; then
  echo "You need to specify a directory"
  exit 255
fi

find $DIR -type f ! -name '*.sig' -exec gpg --batch --yes --output {}.sig --sign {} \;

