#!/bin/bash

PFSRC="$1"

if ! [ -d "$PFSRC" ]; then
  echo "The source directory specified ($PFSRC) doesn't exist"
  exit 1
else
  echo "Building golang sources from $PFSRC"
fi

export GOPATH=`mktemp -d`
export GOBIN="$GOPATH/bin"

cd "$GOPATH"
GOPATHPF="$GOPATH/src/github.com/inverse-inc/packetfence"
mkdir -p $GOPATHPF
cp -a $PFSRC/* "$GOPATHPF/"

cd "$GOPATHPF"

cd go

#TODO: replace with vendoring solution
govendor sync

# Create any binaries here
make pfhttpd

# Delete the GOPATH
rm -fr $GOPATH

