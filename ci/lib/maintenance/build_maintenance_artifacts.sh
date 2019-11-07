#!/bin/bash
set -o nounset -o pipefail -o errexit

die() {
    echo "$(basename $0): $@" >&2 ; exit 1
}

log_section() {
   printf '=%.0s' {1..72} ; printf "\n"
   printf "=\t%s\n" "" "$@" ""
}


configure_and_check() {
    # Define RESULT_DIR if in CI
    if [ ! -z "$CI_PROJECT_DIR" ]
    then
    	RESULT_DIR="$CI_PROJECT_DIR/result"
    fi
    RESULT_DIR=${RESULT_DIR:-result}

    # RELEASE_ID is for example : debian ubuntu mint
    # RELEASE_NAME is for example : jessie xenial
    RELEASE=$(ci-release)
    RELEASE_ID=$(cut -d/ -f1 <<< $RELEASE)
    RELEASE_NAME=$(cut -d/ -f2 <<< $RELEASE)
    RELEASE_DIR=$RESULT_DIR/$RELEASE_ID/$RELEASE_NAME
    # CI_COMMIT_REF_NAME = branch name
    MAINT_DIR=${RELEASE_DIR}/${CI_COMMIT_REF_NAME}

    declare -p RELEASE RELEASE_ID RELEASE_NAME RELEASE_DIR MAINT_DIR

    [ -z "$RELEASE_ID" ] && die "not set: RELEASE_ID"
    [ -z "$RELEASE_NAME" ] && die "not set: RELEASE_NAME"
    [ -z "$RESULT_DIR" ] && die "not set: RESULT_DIR"
    [ -z "$MAINT_DIR" ] && die "not set: MAINT_DIR"
    
    mkdir -vp $MAINT_DIR || die "mkdir failed: $MAINT_DIR"
}

build_golang_binaries() {
    GODIR=${GODIR:-go}

    make -C ${GODIR} all
    make -C ${GODIR} SBINDIR=${MAINT_DIR} copy
}

build_admin_artifacts() {
    echo "test"
}

log_section "Configure and check..."
configure_and_check

log_section "Build Golang binaries..."
build_golang_binaries

log_section "Golang artifacts..."
tree $RELEASE_DIR

log_section "Build web admin artifacts"
build_admin_artifacts

log_section "Web admin artifacts..."
tree $RELEASE_DIR
