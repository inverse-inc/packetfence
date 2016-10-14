#!/bin/bash

DIR="/tmp/scripts"

find $DIR -type f ! -name '*.sig' -exec gpg --batch --yes --output {}.sig --sign {} \;

