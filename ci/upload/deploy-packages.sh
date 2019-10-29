#!/bin/bash
set -o nounset -o pipefail -o errexit

die() {
    echo "$(basename $0): $@" >&2 ; exit 1
}

BASE_DIRECTORY=${BASE_DIRECTORY:-/var/www/repos/PacketFence}
DEPLOY_USER=${DEPLOY_USER:-reposync}
DEPLOY_HOST=${DEPLOY_HOST:-pfbuilder.inverse}
DEPLOY_UPDATE=${DEPLOY_UPDATE:-"hostname -f"}

RPM_DEPLOY_DIR=${RPM_DEPLOY_DIR:-devel/x86_64}
RPM_PUBLIC_DIR=${RPM_PUBLIC_DIR:-public/centos}

DEB_UPLOAD_DIR=${DEB_UPLOAD_DIR:-/root/debian/UploadQueue}
DEB_DEPLOY_DIR=${DEB_DEPLOY_DIR:-debian-devel}
DEB_RESULT_DIR=${DEB_RESULT_DIR:-result/debian}

rpm_deploy() {
    for release_name in $(ls $RPM_PUBLIC_DIR/*); do
        src_dir="$RPM_PUBLIC_DIR/${release_name}/x86_64/"
        dst_repo="$BASE_DIRECTORY/$RPM_DEPLOY_DIR"
        dst_dir="$DEPLOY_USER@$DEPLOY_HOST:$dst_repo"
        declare -p src_dir dst_dir
        echo "copy: $src_dir -> $dst_dir"
        scp $src_dir/*.rpm $dst_dir/RPMS \
            || die "scp failed"

        dst_cmd="$DEPLOY_USER@$DEPLOY_HOST $DEPLOY_UPDATE"
        echo "update: $dst_cmd"
        ssh $dst_cmd \
            || die "update failed"
    done
}

deb_deploy() {
    for release_name in $(ls $DEB_RESULT_DIR/*); do
        src_dir="$DEB_RESULT_DIR/${release_name}"
        dst_dir="$DEPLOY_USER@$DEPLOY_HOST:$DEB_UPLOAD_DIR"
        changes_file=$(ls $DEB_RESULT_DIR/${release_name}/*.changes | tail -1)
        declare -p src_dir dst_dir changes_file
        echo "copy: $src_dir -> $dst_dir"
        scp $src_dir/* $dst_dir/ \
            || die "scp failed"
        
        dst_cmd="$DEPLOY_USER@$DEPLOY_HOST $DEPLOY_UPDATE"
        extra_args="${release_name} ${changes_file}"
        echo "update: $dst_cmd $extra_args"
        ssh $dst_cmd $extra_args\
            || die "update failed"
    done
}

case $1 in
    rpm) rpm_deploy ;;
    deb) deb_deploy ;;
    *)   die "Missing argument"
esac




