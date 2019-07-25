#!/bin/bash -e

GOBIN=${GOBIN:-/usr/local/go/bin}
GOPATH=$HOME/go
GOVENDOR=$GOPATH/bin/govendor
GOPFDIR=${GOPFDIR:-/root/go/src/github.com/inverse-inc/packetfence/go}
PATH=$GOBIN:$PATH

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

get_govendor_binary() {
    log_section "Get govendor binary"
    # will place govendor binary in $HOME/go/bin
    $GOBIN/go get -u github.com/kardianos/govendor
}

get_pf_dependencies() {
    log_section "Get PF dependencies"
    ( cd $GOPFDIR; $GOVENDOR sync )
}

get_govendor_binary
get_pf_dependencies
