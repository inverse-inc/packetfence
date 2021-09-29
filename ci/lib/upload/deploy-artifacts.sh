#!/bin/bash
set -o nounset -o pipefail -o errexit

# full path to dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
PF_SRC_DIR=$(echo ${SCRIPT_DIR} | grep -oP '.*?(?=\/ci\/)')

# path to all functions
FUNCTIONS_FILE=${PF_SRC_DIR}/ci/lib/common/functions.sh

source ${FUNCTIONS_FILE}
get_pf_release

RESULT_DIR=${RESULT_DIR:-result}
PUBLIC_DIR=${PUBLIC_DIR:-public}

DEPLOY_USER=${DEPLOY_USER:-reposync}
DEPLOY_HOST=${DEPLOY_HOST:-web.inverse.ca}

PUBLIC_REPO_BASE_DIR=${PUBLIC_REPO_BASE_DIR:-/var/www/inverse.ca/downloads/PacketFence}

# RPM
DEPLOY_SRPMS=${DEPLOY_SRPMS:-no}
RPM_BASE_DIR=${RPM_BASE_DIR:-"${PUBLIC_REPO_BASE_DIR}"}
RPM_DEPLOY_DIR=${RPM_DEPLOY_DIR:-"${PF_MINOR_RELEASE}/x86_64"}
RPM_RESULT_DIR=${RPM_RESULT_DIR:-"${RESULT_DIR}/centos"}

# Deb
DEB_UPLOAD_DIR=${DEB_UPLOAD_DIR:-"/home/$DEPLOY_USER/debian/UploadQueue"}
DEB_BASE_DIR=${DEB_BASE_DIR:-"${PUBLIC_REPO_BASE_DIR}"}
DEB_DEPLOY_DIR=${DEB_DEPLOY_DIR:-foo}
DEB_RESULT_DIR=${DEB_RESULT_DIR:-"${RESULT_DIR}/debian"}

# Maintenance
GITLAB_DEPLOY_DIR=${GITLAB_DEPLOY_DIR:-tmp}

# CI
# automatically set up by CI based on environment
CI_ENV_NAME=${CI_ENVIRONMENT_NAME:-environment}

rpm_deploy() {
    for release_name in $(ls $RPM_RESULT_DIR); do
        src_dir="$RPM_RESULT_DIR/${release_name}"
        base_repo="$RPM_BASE_DIR/RHEL$release_name/$RPM_DEPLOY_DIR"
        rpm_dir="$base_repo/RPMS"
        dst_dir="$DEPLOY_USER@$DEPLOY_HOST:$rpm_dir"
        deploy_cmd="/usr/local/bin/ci-repo-deploy rpm $base_repo $CI_ENV_NAME"
        declare -p src_dir dst_dir

        # dest repo + subdirectories RPMS need to exist
        # repodata dir will be created by createrepo command
        mkdir_cmd="$DEPLOY_USER@$DEPLOY_HOST mkdir -p $rpm_dir"
        echo "running following command: $mkdir_cmd"
        ssh $mkdir_cmd \
            || die "remote mkdir failed"

        if [ "$DEPLOY_SRPMS" == "no" ]; then
            echo "Removing SRPMS according to '$DEPLOY_SRPMS' value"
            rm -v $src_dir/*.src.rpm
        else
            echo "Keeping SRPMS according to '$DEPLOY_SRPMS' value"
        fi

        # copy rpm files
        echo "copy: $src_dir/*.rpm -> $dst_dir"
        scp $src_dir/*.rpm $dst_dir \
            || die "scp failed"

        # update repository
        dst_cmd="$DEPLOY_USER@$DEPLOY_HOST $deploy_cmd"
        echo "running following command: $dst_cmd"
        ssh $dst_cmd \
            || die "update failed"
    done
}

deb_deploy() {
    for release_name in $(ls $DEB_RESULT_DIR); do
        src_dir="$DEB_RESULT_DIR/${release_name}"
        dst_repo="$DEB_BASE_DIR/$DEB_DEPLOY_DIR/$PF_MINOR_RELEASE"
        dst_dir="$DEPLOY_USER@$DEPLOY_HOST:$DEB_UPLOAD_DIR"
        changes_file=$(basename $(ls $DEB_RESULT_DIR/${release_name}/*.changes | tail -1))
        declare -p src_dir dst_dir changes_file

        # dest repo need to exist + conf directory
        mkdir_cmd="$DEPLOY_USER@$DEPLOY_HOST mkdir -p $dst_repo/conf"
        echo "running following command: $mkdir_cmd"
        ssh $mkdir_cmd \
            || die "remote mkdir failed"

        echo "copy: $src_dir/* -> $dst_dir"
        scp $src_dir/* $dst_dir/ \
            || die "scp failed"

        deploy_cmd="/usr/local/bin/ci-repo-deploy deb $dst_repo $CI_ENV_NAME"
        dst_cmd="$DEPLOY_USER@$DEPLOY_HOST $deploy_cmd"
        extra_args="${release_name} ${changes_file}"
        echo "running following command: $dst_cmd $extra_args"
        ssh $dst_cmd $extra_args \
            || die "update failed"
    done
}

# no deploy command because it's just a file
packetfence_release_deploy() {
    for release_name in $(ls $RPM_RESULT_DIR); do
        src_dir="$RPM_RESULT_DIR/${release_name}"
        dst_repo="$PUBLIC_REPO_BASE_DIR/RHEL$release_name"
        dst_dir="$DEPLOY_USER@$DEPLOY_HOST:$dst_repo"
        pf_release_rpm_file=$(basename $(ls $src_dir/packetfence-release*))
        pkg_dest_name=${PKG_DEST_NAME:-"packetfence-release-${PF_MINOR_RELEASE}.el${release_name}.noarch.rpm"}
        declare -p src_dir dst_dir pf_release_rpm_file pkg_dest_name

        echo "scp: ${src_dir}/${pf_release_rpm_file} -> ${dst_dir}/${pkg_dest_name}"
        scp "${src_dir}/${pf_release_rpm_file}" "${dst_dir}/${pkg_dest_name}" \
            || die "scp failed"
    done
}

# no deploy command because it's just a file
packetfence_export_deploy() {
    # EL
    for release_name in $(ls $RPM_RESULT_DIR); do
        src_dir="$RPM_RESULT_DIR/${release_name}"
        dst_repo="$PUBLIC_REPO_BASE_DIR/RHEL$release_name"
        dst_dir="$DEPLOY_USER@$DEPLOY_HOST:$dst_repo"
        pf_export_rpm_file=$(basename $(ls $src_dir/packetfence-export*))
        pf_export_rpm_dest_name=${PF_EXPORT_RPM_DEST_NAME:-"packetfence-export-${PF_MINOR_RELEASE}.el${release_name}.noarch.rpm"}
        declare -p src_dir dst_dir pf_export_rpm_file pf_export_rpm_dest_name

        echo "scp: ${src_dir}/${pf_export_rpm_file} -> ${dst_dir}/${pf_export_rpm_dest_name}"
        scp "${src_dir}/${pf_export_rpm_file}" "${dst_dir}/${pf_export_rpm_dest_name}" \
            || die "scp failed"
    done
    # Deb
    for release_name in $(ls $DEB_RESULT_DIR); do
        src_dir="$DEB_RESULT_DIR/${release_name}"
        dst_repo="$DEB_BASE_DIR/debian"
        dst_dir="$DEPLOY_USER@$DEPLOY_HOST:$dst_repo"
        pf_export_deb_file=$(basename $(ls $src_dir/packetfence-export*))
        pf_export_deb_dest_name=${PF_EXPORT_DEB_DEST_NAME:-"packetfence-export_${PF_MINOR_RELEASE}.deb"}
        declare -p src_dir dst_dir pf_export_deb_file pf_export_deb_dest_name

        echo "scp: ${src_dir}/${pf_export_deb_file} -> ${dst_dir}/${pf_export_deb_dest_name}"
        scp "${src_dir}/${pf_export_deb_file}" "${dst_dir}/${pf_export_deb_dest_name}" \
            || die "scp failed"
    done
}

ppa_deploy() {
    # warning: slashs at end of dirs are significant for rsync
    src_dir="$PUBLIC_DIR/"
    dst_repo="$PUBLIC_REPO_BASE_DIR/gitlab/$GITLAB_DEPLOY_DIR/"
    dst_dir="$DEPLOY_USER@$DEPLOY_HOST:$dst_repo"
    declare -p src_dir dst_dir
    echo "rsync: $src_dir -> $dst_dir"
    rsync -avz $src_dir $dst_dir \
        || die "rsync failed"
}

log_section "Display artifacts"
tree ${RESULT_DIR}

log_section "Display PacketFence minor release"
echo "${PF_MINOR_RELEASE}"

log_section "Deploy $1 artifacts"
case $1 in
    rpm) rpm_deploy ;;
    deb) deb_deploy ;;
    packetfence-release) packetfence_release_deploy ;;
    packetfence-export) packetfence_export_deploy ;;
    ppa) ppa_deploy ;;
    *)   die "Wrong argument"
esac
