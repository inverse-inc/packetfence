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

DEB_DIR=${PF_SRC_DIR}/debian
DEB_CHLOG=${DEB_DIR}/changelog

configure_and_check() {
    log_subsection "Get current PacketFence version"    
    echo "${PF_PATCH_RELEASE}"
    log_subsection "Get new PacketFence version"
    read -p "New PacketFence version: " PF_NEW_PATCH_RELEASE
}

update_pf_version() {
    local cur_release=${PF_PATCH_RELEASE}
    local new_release=${PF_NEW_PATCH_RELEASE}

    log_subsection "${PF_RELEASE_PATH}"
    sed -i -e "s/^PacketFence .*/PacketFence ${new_release}/" "${PF_RELEASE_PATH}"
    head -n1 ${PF_RELEASE_PATH}
}

update_changelog() {
    update_deb_changelog
}

update_deb_changelog() {
    log_subsection "Debian Changelog"
    local date=$(date -R)
    sed -i -e "1 i\packetfence (${PF_NEW_PATCH_RELEASE}) unstable; urgency=low\n\n  * Version ${PF_NEW_PATCH_RELEASE}\n\n -- Inverse <info@inverse.ca>  ${date}\n" \
        ${DEB_CHLOG} || die "sed failed"
    head -n3 $DEB_CHLOG
}

log_section "Configure and check"
configure_and_check

log_section "Update PacketFence version"
update_pf_version

log_section "Update Changelog"
update_changelog
