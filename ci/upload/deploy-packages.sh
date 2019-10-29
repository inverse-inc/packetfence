#!/bin/bash
set -o nounset -o pipefail -o errexit

die() {
    echo "$(basename $0): $@" >&2 ; exit 1
}

log_section() {
   printf '=%.0s' {1..72} ; printf "\n"
   printf "=\t%s\n" "" "$@" ""
}

DEPLOY_USER=${DEPLOY_USER:-reposync}
DEPLOY_HOST=${DEPLOY_HOST:-pfbuilder.inverse}
DEPLOY_UPDATE=${DEPLOY_UPDATE:-"hostname -f"}

RPM_BASE_DIR=${RPM_BASE_DIR:-/var/www/repos/PacketFence/RHEL7}
RPM_DEPLOY_DIR=${RPM_DEPLOY_DIR:-devel/x86_64}
RPM_RESULT_DIR=${RPM_RESULT_DIR:-result/centos}

DEB_UPLOAD_DIR=${DEB_UPLOAD_DIR:-/root/debian/UploadQueue}
DEB_DEPLOY_DIR=${DEB_DEPLOY_DIR:-debian-devel}
DEB_RESULT_DIR=${DEB_RESULT_DIR:-result/debian}

rpm_deploy() {
    for release_name in $(ls $RPM_RESULT_DIR); do
        src_dir="$RPM_RESULT_DIR/${release_name}"
        dst_repo="$RPM_BASE_DIR/$RPM_DEPLOY_DIR"
        dst_dir="$DEPLOY_USER@$DEPLOY_HOST:$dst_repo"
        declare -p src_dir dst_dir
        echo "copy: $src_dir -> $dst_dir/RPMS"
        scp $src_dir/*.rpm $dst_dir/RPMS \
            || die "scp failed"

        dst_cmd="$DEPLOY_USER@$DEPLOY_HOST $DEPLOY_UPDATE"
        echo "running following command: $dst_cmd"
        ssh $dst_cmd \
            || die "update failed"
    done
}

deb_deploy() {
    for release_name in $(ls $DEB_RESULT_DIR); do
        src_dir="$DEB_RESULT_DIR/${release_name}"
        dst_dir="$DEPLOY_USER@$DEPLOY_HOST:$DEB_UPLOAD_DIR"
        changes_file=$(basename $(ls $DEB_RESULT_DIR/${release_name}/*.changes | tail -1))
        declare -p src_dir dst_dir changes_file
        echo "copy: $src_dir -> $dst_dir"
        scp $src_dir/* $dst_dir/ \
            || die "scp failed"
        
        dst_cmd="$DEPLOY_USER@$DEPLOY_HOST $DEPLOY_UPDATE"
        extra_args="${release_name} ${changes_file}"
        echo "running following command: $dst_cmd $extra_args"
        ssh $dst_cmd $extra_args\
            || die "update failed"
    done
}

log_section "Display artifacts"
tree result

log_section "Deploy $1 packages"
case $1 in
    rpm) rpm_deploy ;;
    deb) deb_deploy ;;
    *)   die "Missing argument"
esac
