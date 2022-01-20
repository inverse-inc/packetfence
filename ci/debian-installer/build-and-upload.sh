#!/bin/bash
set -o nounset -o pipefail -o errexit

PF_RELEASE="`echo $PF_RELEASE | sed -r 's/.*\b([0-9]+\.[0-9]+)\.[0-9]+/\1/g'`"

ISO_NAME=PacketFence-ISO-${PF_VERSION}.iso

# upload
SF_RESULT_DIR=results/sf/${PF_VERSION}
PUBLIC_REPO_DIR="/home/frs/project/p/pa/packetfence/PacketFence\ ISO/${PF_VERSION}"
DEPLOY_SF_USER=${DEPLOY_SF_USER:-inverse-bot,packetfence}
DEPLOY_SF_HOST=${DEPLOY_SF_HOST:-frs.sourceforge.net}

upload_to_sf() {
    # warning: slashs at end of dirs are significant for rsync
    local src_dir="${SF_RESULT_DIR}/"
    local dst_repo="${PUBLIC_REPO_DIR}/"
    local dst_dir="${DEPLOY_SF_USER}@${DEPLOY_SF_HOST}:${dst_repo}"
    declare -p src_dir dst_dir
    echo "rsync: $src_dir -> $dst_dir"

    # quotes to handle space in filename
    rsync -avz $src_dir "$dst_dir"
}

mkdir -p ${SF_RESULT_DIR}

# Manifest need to be generate by hand because we modify OVF during last step
echo "===> Build ISO for release $PF_RELEASE"
PF_RELEASE=$PF_RELEASE ISO_OUT="${SF_RESULT_DIR}/${ISO_NAME}" sudo /var/local/gitlab-runner/builds/EGRXY5p9/0/inverse-inc/packetfence/ci/debian-installer/create-debian-installer.sh

echo "===> Upload to Sourceforge"
upload_to_sf
