#!/bin/bash

PATH="/usr/local/go/bin:$PATH"

MODE="$1"
PFSRC="$2"
BINDST="$3"

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

find $PFSRC -maxdepth 1 -type d ! -name 'logs' ! -name 'var' ! -name 'pf' -exec cp -a {} "$GOPATHPF/" \;

cd "$GOPATHPF"

cd go

# Install the dependencies
govendor sync

if build_mode; then
  # Create any binaries here and make sure to move them to the BINDST specified
  make pfhttpd
  mv pfhttpd $BINDST/
elif test_mode; then
  PFCONFIG_TESTING=y govendor test ./...  
fi

