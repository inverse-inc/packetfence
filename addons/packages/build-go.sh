#!/bin/bash

PATH="/usr/local/go/bin:$PATH"

MODE="$1"
PFSRC="$2"
BINDST="$3"
DEBPATH="$4"

function usage {
  echo "----------------------------------------------------------------------------"
  echo "Usage        : build-go.sh test|build [args]"
  echo "Build usage  : build-go.sh build /path/to/pf-sources /path/to/built/binaries"
  echo "Test usage   : build-go.sh test /path/to/pf-sources"
  echo "----------------------------------------------------------------------------"
}

function test_mode {
  [[ "$MODE" == "test" ]]
  return $?
}

function build_mode {
  [[ "$MODE" == "build" ]]
  return $?
}

if ! test_mode && ! build_mode ; then
  echo "!!!!!! - You need to specify a valid mode (test|build)"
  usage
  exit 1
fi

if ! [ -d "$PFSRC" ]; then
  echo "!!!!!! - The source directory specified ($PFSRC) doesn't exist"
  usage
  exit 1
else
  echo "Building golang sources from $PFSRC"
fi

if build_mode && ! [ -d "$BINDST" ]; then
  echo "!!!!!! - The binary destination specified ($BINDST) doesn't exist."
  usage
  exit 1
else
  echo "Will place binaries in $BINDST"
fi

set -x


if [ -z "$DEBPATH" ]; then
    export GOPATH=`mktemp -d`
else
    export GOPATH=`mktemp -d -p $DEBPATH`
fi

export GOPATH

export GOBIN="$GOPATH/bin"

# Exit hook to cleanup the tmp GOPATH when exiting
function cleanup {
  rm -rf "$GOPATH"
}
trap cleanup EXIT

cd "$GOPATH"
GOPATHPF="$GOPATH/src/github.com/inverse-inc/packetfence"
mkdir -p $GOPATHPF


find $PFSRC -maxdepth 1 -type d ! -path '*/debian' ! -path '*/logs' ! -path '*/var' ! -path '*/docs' ! -path '*/t' ! -path '*/db' ! -path '*/addons' ! -path '*/.tx' -exec cp -a {} "$GOPATHPF/" \;

cd "$GOPATHPF"

cd go

# Ensure current binaries are available through path
export PATH="$GOBIN:$PATH"

# Install the dependencies
go get -u github.com/kardianos/govendor
$GOPATH/bin/govendor sync

if build_mode; then
  # Create any binaries here and make sure to move them to the BINDST specified
  for service in pfdns pfstats pfdetect;do
      make $service
      mv $service $BINDST/
  done

elif test_mode; then
  make test
fi
