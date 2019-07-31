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
    local repo=$1
    local extra_path=$2
    log_section "Getting $repo/$extra_path Golang dependencies"
    declare -p GOPATH repo extra_path
    ( cd $GOPATH/src/$repo/$extra_path; $GOVENDOR sync )
}

move_vendor_dependencies() {
    log_section "Moving vendor dependencies to $GOROOT"
    local vendor_deps_dirs=$(find $GO_REPO/$EXTRA_PATH/vendor/* -maxdepth 0 -type d)
    declare -p vendor_deps_dirs
    for vendor_dir in vendor_deps_dirs; do
        mv $vendor_dir $GOROOT/src
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

get_govendor_binary
get_app_dependencies $GO_REPO $EXTRA_PATH
move_vendor_dependencies
clear_cache
