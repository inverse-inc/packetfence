#!/bin/bash
set -o nounset -o pipefail -o errexit

# Build the packetfence-perl Debian package locally, the same way CI does.
#
# Two steps, mirroring .github/workflows/packetfence-perl_build_image_package.yml:
#   1. build the packetfence-perl-<distro> image, which compiles every CPAN
#      distribution listed in addons/packetfence-perl/dependencies.csv into
#      /usr/local/pf/lib/perl_modules (long: expect tens of minutes)
#   2. run addons/packetfence-perl/build_package.sh inside that image, which tars
#      that tree and wraps it with dpkg-buildpackage
#
# The resulting .deb only works on the distro it was built on: it ships XS
# modules compiled against that base image's perl.

# full path to dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources (strip containers/packetfence-perl)
PF_SRC_DIR=${SCRIPT_DIR%/*/*}

PKG_SRC_DIR="${PF_SRC_DIR}/addons/packetfence-perl"
CHANGELOG="${PKG_SRC_DIR}/debian/changelog"

# defaults, all overridable through options or the environment
DISTRO="${DISTRO:-debian13}"
OUTPUT_DIR="${OUTPUT_DIR:-}"
IMAGE_NAME="${IMAGE_NAME:-}"
WORKDIR="${WORKDIR:-/root}"
CONTAINER_OUTPUT_DIR="${CONTAINER_OUTPUT_DIR:-/mnt/output/}"
BUILD_IMAGE=1
VALIDATE=1
CI_MOUNT=0
NO_CACHE=0

function usage {
    cat <<EOF
Usage: ${0##*/} [options]

Build packetfence-perl_<version>_all.deb inside a throwaway Docker image.

Options:
  -d, --distro DISTRO   distro to build for, must match a directory holding a
                        Dockerfile_<distro> (default: ${DISTRO})
  -o, --output DIR      host directory to write the package to
                        (default: /tmp/packetfence-perl/<distro>)
  -t, --tag IMAGE       image name:tag to build and run
                        (default: packetfence-perl-<distro>:<changelog version>)
  -s, --skip-image      reuse an existing image, only run the packaging step
  -n, --no-validate     skip the install_cpan.py version check before packaging
      --ci-mount        mount the sources over ${WORKDIR} exactly like CI does,
                        instead of copying debian/ in from a read-only mount
      --no-cache        pass --no-cache to docker build
  -h, --help            this message

Available distros: $(cd "${SCRIPT_DIR}" && ls -d */ 2>/dev/null | tr -d / | tr '\n' ' ')

Examples:
  ${0##*/}                          # build for Debian 13 (trixie)
  ${0##*/} -d debian12              # build for Debian 12 (bookworm)
  ${0##*/} -s -o /tmp/out           # repackage from an image built earlier
EOF
}

function die {
    echo "ERROR: $*" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--distro)      DISTRO="$2"; shift 2 ;;
        -o|--output)      OUTPUT_DIR="$2"; shift 2 ;;
        -t|--tag)         IMAGE_NAME="$2"; shift 2 ;;
        -s|--skip-image)  BUILD_IMAGE=0; shift ;;
        -n|--no-validate) VALIDATE=0; shift ;;
        --ci-mount)       CI_MOUNT=1; shift ;;
        --no-cache)       NO_CACHE=1; shift ;;
        -h|--help)        usage; exit 0 ;;
        *)                usage >&2; die "unknown option: $1" ;;
    esac
done

DOCKERFILE="${SCRIPT_DIR}/${DISTRO}/Dockerfile_${DISTRO}"

[ -f "${DOCKERFILE}" ] || die "no Dockerfile for '${DISTRO}' at ${DOCKERFILE}"
[ -f "${CHANGELOG}" ] || die "changelog not found at ${CHANGELOG}"
command -v docker >/dev/null || die "docker is not installed"

case "${DISTRO}" in
    debian*) ;;
    *) die "only debian* is supported here; ${DISTRO} needs build secrets, use CI" ;;
esac

# same version CI derives with 'dpkg-parsechangelog --show-field Version', but
# without needing dpkg-dev on the host
VERSION=$(sed -nE '1s/^[^(]*\(([^)]+)\).*/\1/p' "${CHANGELOG}")
[ -n "${VERSION}" ] || die "could not parse a version out of ${CHANGELOG}"

IMAGE_NAME="${IMAGE_NAME:-packetfence-perl-${DISTRO}:${VERSION}}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/packetfence-perl/${DISTRO}}"

mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR=$(readlink -e "${OUTPUT_DIR}")
BUILD_LOG="${OUTPUT_DIR}/docker-build.log"

echo "distro:      ${DISTRO}"
echo "dockerfile:  ${DOCKERFILE}"
echo "version:     ${VERSION} (from debian/changelog)"
echo "image:       ${IMAGE_NAME}"
echo "output:      ${OUTPUT_DIR}"
echo

if [ "${BUILD_IMAGE}" -eq 1 ]; then
    echo "==> building image (this compiles every dist in dependencies.csv, be patient)"
    echo "    full log: ${BUILD_LOG}"
    build_opts=()
    [ "${NO_CACHE}" -eq 1 ] && build_opts+=(--no-cache)
    # context is the repo root: the Dockerfile COPYs from ./addons/packetfence-perl/
    docker build \
        "${build_opts[@]}" \
        -f "${DOCKERFILE}" \
        --build-arg workdir="${WORKDIR}" \
        --build-arg output_directory="${CONTAINER_OUTPUT_DIR}" \
        -t "${IMAGE_NAME}" \
        "${PF_SRC_DIR}" 2>&1 | tee "${BUILD_LOG}"
else
    echo "==> skipping image build, reusing ${IMAGE_NAME}"
    docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1 \
        || die "image ${IMAGE_NAME} not found, drop --skip-image to build it"
fi

# build_package.sh needs debian/{control,rules,changelog}, which the image does
# not carry: its COPY only brings in four files and leaves ${WORKDIR}/debian empty.
if [ "${VALIDATE}" -eq 1 ]; then
    validate_cmd="python3 install_cpan.py -d dependencies.csv -vi true"
else
    validate_cmd="true"
fi

echo
echo "==> building package"
if [ "${CI_MOUNT}" -eq 1 ]; then
    # exactly what CI does: sources mounted over ${WORKDIR}, which also shadows
    # the /root/.cpan config baked into the image
    docker run --rm \
        -v "${PKG_SRC_DIR}:${WORKDIR}" \
        -v "${OUTPUT_DIR}:/mnt/output" \
        "${IMAGE_NAME}" \
        bash -c "set -e && cd ${WORKDIR} && ${validate_cmd} && ./build_package.sh"
else
    # keep the image's CPAN config intact: mount read-only elsewhere and copy
    # only the packaging metadata into place
    docker run --rm \
        -v "${PKG_SRC_DIR}:/src:ro" \
        -v "${OUTPUT_DIR}:/mnt/output" \
        "${IMAGE_NAME}" \
        bash -c "set -e && cp -r /src/debian/. ${WORKDIR}/debian/ && cd ${WORKDIR} && ${validate_cmd} && ./build_package.sh"
fi

DEB=$(find "${OUTPUT_DIR}/debian/packages" -name 'packetfence-perl_*.deb' -print -quit 2>/dev/null || true)
[ -n "${DEB}" ] || die "build reported success but no .deb landed in ${OUTPUT_DIR}/debian/packages"

echo
echo "==> done: ${DEB}"
ls -lh "${DEB}"
dpkg-deb -f "${DEB}" Package Version Architecture Depends 2>/dev/null || true
