#!/bin/bash

set -x

PFSRC="$1"
BINDST="$2"
SHOULD_TEST=${SHOULD_TEST:-"1"}

if ! [ -d "$PFSRC" ]; then
  echo "The source directory specified ($PFSRC) doesn't exist"
  exit 1
else
  echo "Building golang sources from $PFSRC"
fi

if ! [ -d "$BINDST" ]; then
  echo "The binary destination specified ($BINDST) doesn't exist."
  exit 1
else
  echo "Will place binaries in $BINDST"
fi

export GOPATH=`mktemp -d`
export GOBIN="$GOPATH/bin"

# Exit hook to cleanup the tmp GOPATH when exiting
function cleanup {
  rm -rf "$GOPATH"
}
trap cleanup EXIT

cd "$GOPATH"
GOPATHPF="$GOPATH/src/github.com/inverse-inc/packetfence"
mkdir -p $GOPATHPF
cp -a $PFSRC/* "$GOPATHPF/"

cd "$GOPATHPF"

cd go

#TODO: replace with vendoring solution
go get ./...
go get -t ./...

if [[ $SHOULD_TEST -eq 1 ]] && ! go test ./...; then
  echo "Failed to execute tests. Will not build."
  exit 1
fi

# Create any binaries here and make sure to move them to the BINDST specified
make pfhttpd
mv pfhttpd $BINDST/

# Delete the GOPATH
rm -fr $GOPATH

