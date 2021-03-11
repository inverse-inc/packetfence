#!/bin/bash
set -o nounset -o pipefail -o errexit

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


configure_and_check() {
    log_section "Configure and check..."
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
    # CI_COMMIT_REF_NAME = branch name = maintenance/X.Y
    # we drop "maintenance/" prefix
    MAINT_DIR=${RELEASE_DIR}/${CI_COMMIT_REF_NAME#maintenance/}

    declare -p RELEASE RELEASE_ID RELEASE_NAME RESULT_DIR RELEASE_DIR MAINT_DIR

    [ -z "$RELEASE_ID" ] && die "not set: RELEASE_ID"
    [ -z "$RELEASE_NAME" ] && die "not set: RELEASE_NAME"
    [ -z "$RESULT_DIR" ] && die "not set: RESULT_DIR"
    [ -z "$MAINT_DIR" ] && die "not set: MAINT_DIR"
    
    mkdir -vp ${MAINT_DIR} || die "mkdir failed: $MAINT_DIR"
}

configure_gpg() {
    log_section "Configure GPG.."
    GPG_KEY_ID=${GPG_KEY_ID:-${GPG_USER_ID}}
}


build_golang_binaries() {
    log_section "Build Golang binaries..."    
    GO_DIR=${GO_DIR:-go}

    make -C ${GO_DIR} all
    log_subsection "Move binaries in ${MAINT_DIR}"
    make -C ${GO_DIR} SBINDIR=${MAINT_DIR} copy
}

build_admin_artifacts() {
    log_section "Build web admin artifacts..."    
    SRC_HTML_DIR=html
    SRC_HTML_PFAPPDIR_ROOT=${SRC_HTML_DIR}/pfappserver/root

    make -C ${SRC_HTML_PFAPPDIR_ROOT} vendor
    make -C ${SRC_HTML_PFAPPDIR_ROOT} light-dist

    log_subsection "Move artifacts in ${MAINT_DIR}"
    tar -v -czf ${MAINT_DIR}/dist.tgz -C ${SRC_HTML_PFAPPDIR_ROOT} dist
}

# build artifact for each distribution
build_artifacts() {
    configure_and_check
    build_golang_binaries
    build_admin_artifacts
    tree $RELEASE_DIR
}

# sign artifacts for all distributions using artifacts
# of previous build jobs
sign_artifacts() {
    if [ ! -z "$CI_PROJECT_DIR" ]; then
        RESULT_DIR="$CI_PROJECT_DIR/result"
    fi
    RESULT_DIR=${RESULT_DIR:-result}
    configure_gpg
    log_section "Display artifacts.."
    tree $RESULT_DIR
    log_section "Sign all artifacts.."
    find $RESULT_DIR -type f -not -name "*.sig" -exec \
         gpg -v -u $GPG_KEY_ID --batch --yes --output {}.sig --sign {} \;
    tree $RESULT_DIR
}

case $1 in
    build) build_artifacts ;;
    sign) sign_artifacts ;;
    *)   die "Wrong argument"
esac
