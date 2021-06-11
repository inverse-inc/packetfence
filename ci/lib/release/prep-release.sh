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

RPM_SPEC=${PF_SRC_DIR}/rpm/packetfence.spec
RPM_SOURCE=${PF_SRC_DIR}/rpm/source
DEB_CHLOG=${PF_SRC_DIR}/debian/changelog

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

    log_subsection "${RPM_SOURCE}"
    sed -i -e "s/${cur_release}/${new_release}/" "${RPM_SOURCE}"
    head -n2 ${RPM_SOURCE}

    log_subsection "${RPM_SPEC}"
    sed -i -e "s/^\(Version:[^0-9]*\).*/\1${new_release}/" "${RPM_SPEC}"
    grep "^Version:" ${RPM_SPEC}
}

update_changelog() {
    update_deb_changelog
    update_rpm_changelog
}

update_deb_changelog() {
    log_subsection "Debian Changelog"
}

update_rpm_changelog() {
    log_subsection "RPM Changelog"
    # to be sure date use only en_US abbreviated locale names
    # export LC_TIME=en_US
    local date=$(date '+%a %b %d %Y')
    local author="Inverse <info@inverse.ca>"
    local pkg_release="${PF_NEW_PATCH_RELEASE}-1"
    # insert content **after** match
    sed -i -e "/%changelog/a * $date $author - $pkg_release\n- New release ${PF_NEW_PATCH_RELEASE}" \
        ${RPM_SPEC}
    grep -A2 "%changelog" ${RPM_SPEC}
}

log_section "Configure and check"
configure_and_check

log_section "Update PacketFence version"
update_pf_version

log_section "Update Changelog"
update_changelog
