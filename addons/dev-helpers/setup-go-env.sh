#!/bin/bash

if [ -d /usr/local/go ]; then
  echo "/usr/local/go exists, refusing to setup"
else
  set -x

  echo "Setting up golang environment for PacketFence"
  GOVERSION=`strings /usr/local/pf/sbin/pfhttpd | egrep -o 'go[0-9]+\.[0-9]+(\.[0-9])*' | head -1`
  wget https://storage.googleapis.com/golang/$GOVERSION.linux-amd64.tar.gz -O /tmp/$GOVERSION.linux-amd64.tar.gz
  tar -C /usr/local -xzf /tmp/$GOVERSION.linux-amd64.tar.gz
  rm /tmp/$GOVERSION.linux-amd64.tar.gz

  SETUP='
export PATH=$PATH:/usr/local/go/bin
export GOPATH=~/gospace
export PATH=~/gospace/bin:$PATH'
  echo "$SETUP" >> ~/.bashrc
  eval "$SETUP"

  mkdir -p $GOPATH/src/github.com/inverse-inc/packetfence

  if [ -d $GOPATH/src/github.com/inverse-inc/packetfence/go ]; then
    echo "Directory $GOPATH/src/github.com/inverse-inc/packetfence/go already exists, cannot symlink it to /usr/local/pf/go"
  else
    ln -s /usr/local/pf/go $GOPATH/src/github.com/inverse-inc/packetfence/go
  fi

fi
