#!/bin/bash -e

GOBIN=${GOBIN:-/usr/local/go/bin}
GOPATH=${GOPATH:-$HOME/go}
GOROOT=/usr/local/go/
GOVENDOR=$GOPATH/bin/govendor
GO_REPO=${GO_REPO:-github.com/inverse-inc/packetfence}
EXTRA_PATH=${EXTRA_PATH}
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
    log_section "Getting govendor binary"
    # will place govendor binary in $HOME/go/bin
    declare -p GOPATH
    $GOBIN/go get -u github.com/kardianos/govendor
}

get_app_dependencies() {
    log_section "Getting $PACKAGE_DIR Golang dependencies"
    declare -p PACKAGE_DIR
    ( cd $PACKAGE_DIR; $GOVENDOR sync )
}

move_vendor_dependencies() {
    log_section "Moving vendor dependencies to $GOROOT"
    local vendor_repos=$(find $VENDOR_DIR/* -maxdepth 0 -type d)
    for vendor_repo in $vendor_repos; do
        echo "Moving $vendor_repo to $GOROOT/src"
        mv $vendor_repo $GOROOT/src
    done
}

clear_cache() {
    local go_cache_dir=$GOPATH/.cache
    log_section "Removing $go_cache_dir directory if present"
    if [ -d "$go_cache_dir" ]; then
        rm -rf $go_cache_dir
    else
        echo "No $go_cache_dir found"
    fi
}

if [ -n "$EXTRA_PATH" ]; then
    PACKAGE_DIR=$GOPATH/src/$GO_REPO/$EXTRA_PATH
else
    PACKAGE_DIR=$GOPATH/src/$GO_REPO
fi
VENDOR_DIR=$PACKAGE_DIR/vendor
declare -p PACKAGE_DIR VENDOR_DIR

get_govendor_binary
get_app_dependencies
move_vendor_dependencies
clear_cache
