#!/bin/bash -e

# GOVERSION, GOPATH can be pass as environment variables

# env variable can override default
GO_REPO=${GO_REPO:-github.com/inverse-inc/packetfence}

die() {
    echo "$(basename $0): $@" >&2 ; exit 1
}

log_section() {
    printf '=%.0s' {1..72} ; printf "\n"
    printf "=\t%s\n" "" "$@" ""
}

log_subsection() {
   printf "=\t%s\n" "" "$@" ""
}

install() {
    log_section "Installing Golang environment for PacketFence"

    if [ -z "$GOVERSION" ]; then
        echo "Trying to detect Go version based on installed binaries"
        GOVERSION=`strings /usr/local/pf/sbin/pfhttpd | egrep -o 'go[0-9]+\.[0-9]+(\.[0-9])*' | head -1`
    fi
    declare -p GOVERSION
    [ -z "$GOVERSION" ] && die "not set: GOVERSION"

    log_subsection "Downloading Golang from upstream"
    curl -s https://storage.googleapis.com/golang/$GOVERSION.linux-amd64.tar.gz -o /tmp/$GOVERSION.linux-amd64.tar.gz
    tar -C /usr/local -xzf /tmp/$GOVERSION.linux-amd64.tar.gz
    rm /tmp/$GOVERSION.linux-amd64.tar.gz
}

setup() {
    SETUP='
export PATH=$PATH:/usr/local/go/bin
export GOPATH=~/gospace
export PATH=~/gospace/bin:$PATH'
    echo "$SETUP" >> ~/.bashrc
    eval "$SETUP"
}

# Main
if [ -d /usr/local/go ]; then
    die "/usr/local/go exists, refusing to setup"
else
    install
fi

log_section "Setup variables and directories for Golang environment"
# we are in a packer build
if [ -n "$PACKER_BUILD_NAME" ]; then
    declare -p GOPATH GO_REPO
    mkdir -v -p $GOPATH/src/$GO_REPO
else
    setup
    declare -p GOPATH GO_REPO
    mkdir -v -p $GOPATH/src/$GO_REPO
    if [ -d $GOPATH/src/$GO_REPO/go ]; then
        die "Directory $GOPATH/src/$GO_REPO/go already exists, cannot symlink it to /usr/local/pf/go"
    else
        ln -s -v /usr/local/pf/go $GOPATH/src/$GO_REPO/go
    fi
fi

