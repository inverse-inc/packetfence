#!/bin/bash
set -o nounset -o pipefail -o errexit

# Build a third-party Debian package from a recipe directory.
# Usage: build.sh <pkg>
#
# A recipe is addons/third-party/<pkg>/ with:
#   recipe.conf  UPSTREAM_VERSION plus either SOURCE_URL + SOURCE_SHA256 (tarball)
#                or SOURCE_GIT + SOURCE_REF (git tag/commit)
#   debian/      packaging; debian/changelog sets the exact version (no CI suffix)
#
# Results land in result/<os id>/<codename>/, the layout deploy-artifacts.sh expects.

# full path to dir of recipes (functions.sh overwrites SCRIPT_DIR)
RECIPES_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# path to all functions, also sets PF_SRC_DIR
FUNCTIONS_FILE=$(readlink -e ${RECIPES_DIR}/../../ci/lib/common/functions.sh)

source ${FUNCTIONS_FILE}

list_recipes() {
    for recipe in ${RECIPES_DIR}/*/recipe.conf; do
        basename $(dirname ${recipe})
    done
}

PKG=${1:-}
if [ -z "${PKG}" ]; then
    echo "Usage: $0 <pkg>" >&2
    echo "Available recipes:" >&2
    list_recipes >&2
    exit 1
fi

RECIPE_DIR=${RECIPES_DIR}/${PKG}
[ -f "${RECIPE_DIR}/recipe.conf" ] || die "no recipe for '${PKG}' (expected ${RECIPE_DIR}/recipe.conf)"
[ -f "${RECIPE_DIR}/debian/changelog" ] || die "missing ${RECIPE_DIR}/debian/changelog"

UPSTREAM_VERSION=
SOURCE_URL=
SOURCE_SHA256=
SOURCE_GIT=
SOURCE_REF=
source ${RECIPE_DIR}/recipe.conf
[ -n "${UPSTREAM_VERSION}" ] || die "UPSTREAM_VERSION not set in recipe.conf"

. /etc/os-release
OS_RELEASE_ID=${ID}
OS_RELEASE_NAME=${VERSION_CODENAME:-${VERSION_ID%%.*}}

WORK_DIR=${WORK_DIR:-${PF_SRC_DIR}/build/third-party/${PKG}}
PKG_RESULT_DIR=${PKG_RESULT_DIR:-${PF_SRC_DIR}/result}
PKG_RELEASE_DIR=${PKG_RESULT_DIR}/${OS_RELEASE_ID}/${OS_RELEASE_NAME}

log_section "Install build tools"
missing_tools=
for tool in mk-build-deps equivs-build dpkg-buildpackage lintian curl git; do
    command -v ${tool} >/dev/null || missing_tools="${missing_tools} ${tool}"
done
if [ -n "${missing_tools}" ]; then
    echo "Missing:${missing_tools}"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential devscripts equivs lintian curl ca-certificates git
fi

SRC_NAME=$(dpkg-parsechangelog -l ${RECIPE_DIR}/debian/changelog -S Source)
DEB_VERSION=$(dpkg-parsechangelog -l ${RECIPE_DIR}/debian/changelog -S Version)
# strip epoch and Debian revision to compare against UPSTREAM_VERSION
CHANGELOG_UPSTREAM=${DEB_VERSION#*:}
CHANGELOG_UPSTREAM=${CHANGELOG_UPSTREAM%-*}
[ "${CHANGELOG_UPSTREAM}" = "${UPSTREAM_VERSION}" ] \
    || die "debian/changelog upstream version '${CHANGELOG_UPSTREAM}' != UPSTREAM_VERSION '${UPSTREAM_VERSION}'"
declare -p PKG SRC_NAME DEB_VERSION WORK_DIR PKG_RELEASE_DIR

ORIG_TARBALL=${WORK_DIR}/${SRC_NAME}_${UPSTREAM_VERSION}.orig.tar.gz
SRC_DIR=${WORK_DIR}/${SRC_NAME}-${UPSTREAM_VERSION}

rm -rf ${WORK_DIR}
mkdir -p ${WORK_DIR}

log_section "Fetch sources"
if [ -n "${SOURCE_URL}" ]; then
    [ -n "${SOURCE_SHA256}" ] || die "SOURCE_SHA256 not set in recipe.conf"
    curl -fsSL -o ${ORIG_TARBALL} "${SOURCE_URL}" \
        || die "download of ${SOURCE_URL} failed"
    echo "${SOURCE_SHA256}  ${ORIG_TARBALL}" | sha256sum -c - \
        || die "checksum mismatch for ${SOURCE_URL}"
elif [ -n "${SOURCE_GIT}" ]; then
    [ -n "${SOURCE_REF}" ] || die "SOURCE_REF not set in recipe.conf"
    git clone --quiet --no-checkout "${SOURCE_GIT}" ${WORK_DIR}/git \
        || die "clone of ${SOURCE_GIT} failed"
    git -C ${WORK_DIR}/git archive --format=tar.gz \
        --prefix=${SRC_NAME}-${UPSTREAM_VERSION}/ \
        -o ${ORIG_TARBALL} "${SOURCE_REF}" \
        || die "git archive of ${SOURCE_REF} failed"
    rm -rf ${WORK_DIR}/git
else
    die "recipe.conf must set SOURCE_URL or SOURCE_GIT"
fi

log_section "Prepare source tree"
mkdir -p ${SRC_DIR}
tar -xzf ${ORIG_TARBALL} -C ${SRC_DIR} --strip-components=1
rm -rf ${SRC_DIR}/debian
cp -a ${RECIPE_DIR}/debian ${SRC_DIR}/debian

log_section "Install build dependencies"
cd ${SRC_DIR}
mk-build-deps -i -r -t 'apt-get -y --no-install-recommends' debian/control
rm -f ${SRC_NAME}-build-deps_*

log_section "Build ${SRC_NAME} ${DEB_VERSION}"
dpkg-buildpackage -us -uc -sa

log_section "Lintian (informational)"
lintian -i ${WORK_DIR}/*.changes || true

log_section "Copy results to ${PKG_RELEASE_DIR}"
mkdir -p ${PKG_RELEASE_DIR}
find ${WORK_DIR} -maxdepth 1 -type f \
    \( -name '*.deb' -o -name '*.dsc' -o -name '*.tar.*' -o -name '*.buildinfo' -o -name '*.changes' \) \
    -exec cp -fv {} ${PKG_RELEASE_DIR}/ \;
