#!/bin/bash
# Host-side wrapper invoked by the Makefile entry targets: runs the
# vagrant-build image with /dev/kvm and hands off to build-in-container.sh.
set -o errexit -o nounset -o pipefail

TARGET="${1:?usage: vagrant-in-docker.sh <make-target> (e.g. pfbox, pfadbox)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# CI sets the image ref; the default comes from containers/vagrant-build/build-local.sh.
: "${VAGRANT_BUILD_IMAGE:=vagrant-build:local-test}"

# Base-box QCOW2 cache shared with the host so it persists across CI jobs.
: "${PACKER_ISO_CACHE_DIR:=/tmp/packer-iso}"

if [[ ! -e /dev/kvm ]]; then
  echo "ERROR: /dev/kvm not present -- the vagrant runner needs KVM exposed." >&2
  exit 1
fi

# Open /dev/kvm via the device's gid instead of --privileged.
KVM_GID="$(stat -c '%g' /dev/kvm)"

mkdir -p "${PACKER_ISO_CACHE_DIR}"

echo "===> vagrant box build in ${VAGRANT_BUILD_IMAGE} (kvm gid=${KVM_GID}, target=${TARGET})"

# The repo is mounted at its host path so CURDIR/RESULT_DIR values computed on
# the host stay valid inside the container. /var/tmp keeps the packer logs on
# the host; the named volume persists the apt-cacher-ng cache across jobs.
# -e without a value forwards the variable from this environment.
docker run --rm \
  --device /dev/kvm \
  --group-add "${KVM_GID}" \
  -e BOX_NAME \
  -e BOX_VERSION \
  -e BOX_DESC \
  -e ANSIBLE_GROUP \
  -e BUILD_NAME \
  -e RESULT_DIR \
  -e VAGRANT_LIBVIRT_VIRT_SYSPREP_OPTIONS \
  -e ANSIBLE_FORCE_COLOR \
  -e UPLOAD_BOX \
  -e REF_SLUG \
  -e RCLONE_ACCESS_KEY_ID \
  -e RCLONE_SECRET_ACCESS_KEY \
  -e RCLONE_LINODE_URL \
  -v "${REPO_ROOT}":"${REPO_ROOT}" \
  -v "${PACKER_ISO_CACHE_DIR}":/tmp/packer-iso \
  -v /var/tmp:/var/tmp \
  -v pf-apt-cacher-ng:/var/cache/apt-cacher-ng \
  -w "${SCRIPT_DIR}" \
  "${VAGRANT_BUILD_IMAGE}" \
  "${SCRIPT_DIR}/build-in-container.sh" "${TARGET}"
