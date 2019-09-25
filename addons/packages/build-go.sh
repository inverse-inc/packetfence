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


cd "$PFSRC"

if build_mode; then
  # Create any binaries here and make sure to move them to the BINDST specified
  for service in pfhttpd pfdhcp pfdns pfstats pfdetect;do
      rm -f $service
      make $service
      mv $service $BINDST/
  done

elif test_mode; then
  make test
fi
