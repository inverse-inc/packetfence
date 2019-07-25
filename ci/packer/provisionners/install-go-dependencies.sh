#!/bin/bash -e

GOBIN=${GOBIN:-/usr/local/go/bin}
GOPATH=${GOPATH:-$HOME/go}
GOVENDOR=$GOPATH/bin/govendor
APP=${APP:-inverse-inc/packetfence}
GO_APP_WORKSPACE=${GO_APP_WORKSPACE:-src/github.com/$APP/go}
# needed by govendor to find go binary
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

get_app_dependencies() {
    local app=$1
    log_section "Get $1 Golang dependencies"
    ( cd $GOPATH/$GO_APP_WORKSPACE; $GOVENDOR sync )
}

get_govendor_binary
get_app_dependencies $APP
