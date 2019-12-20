#!/bin/bash
set -o nounset -o pipefail -o errexit

die() {
    echo "$(basename $0): $@" >&2 ; exit 1
}

log_section() {
   printf '=%.0s' {1..72} ; printf "\n"
   printf "=\t%s\n" "" "$@" ""
}

RESULT_DIR=${RESULT_DIR:-result}

DEPLOY_USER=${DEPLOY_USER:-reposync}
DEPLOY_HOST=${DEPLOY_HOST:-pfbuilder.inverse}

REPO_BASE_DIR=${REPO_BASE_DIR:-/var/www/repos/PacketFence}
PUBLIC_REPO_BASE_DIR=${PUBLIC_REPO_BASE_DIR:-/var/www/inverse.ca/downloads/PacketFence}

MAINT_DEPLOY_DIR=${MAINT_DEPLOY_DIR:-tmp}

maint_deploy() {
    # warning: slashs at end of dirs are significant for rsync
    src_dir="$RESULT_DIR/"
    dst_repo="$PUBLIC_REPO_BASE_DIR/$MAINT_DEPLOY_DIR/"
    dst_dir="$DEPLOY_USER@$DEPLOY_HOST:$dst_repo"
    declare -p src_dir dst_dir
    echo "rsync: $src_dir -> $dst_dir"
    rsync -avz $src_dir $dst_dir \
        || die "scp failed"
}


log_section "Display artifacts"
tree ${RESULT_DIR}

log_section "Deploy $1 artifacts"
case $1 in
    maintenance) maint_deploy ;;
    *)   die "Wrong argument"
esac
