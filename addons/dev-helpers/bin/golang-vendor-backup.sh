#!/bin/bash

###
# Script to backup the Golang dependencies
# Should be used on a trusted backed up machine
# This will first clone or update the git repo, then will sync all the Golang dependencies using govendor
# That way if a dependency is ever deleted or accidently force-pushed, then the product of this script could be used as a fallback
###

script_dir=`pwd`

mkdir -p goroot
GOPATH=$script_dir/goroot

if ! ls $GOPATH/src/github.com/inverse-inc/packetfence >/dev/null 2>&1; then
  go get github.com/inverse-inc/packetfence
fi

if ! cd $GOPATH/src/github.com/inverse-inc/packetfence; then
  echo "Can't go in PacketFence git directory"
  exit 1
fi

echo "Synchronizing git directory"
if ! git pull; then
  echo "Can't fetch latest data for PacketFence repo"
  exit 1
fi

if ! cd go; then
  echo "Can't go in the go/ directory of PacketFence"
  exit 1
fi

echo "Synchronizing dependencies"
if ! $script_dir/govendor sync; then
  echo "Unable to sync the dependencies"
  exit 1
fi

echo "Completed sync"

