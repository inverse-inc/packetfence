#!/bin/bash
# Host-side wrapper invoked by `make zen-deb12`: runs the zen-builder
# image with /dev/kvm and hands off to build-in-container.sh.
set -o errexit -o nounset -o pipefail

BUILD_NAME="${1:?usage: zen-in-docker.sh <build-name> (e.g. debian-12)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CI sets the image ref; the default comes from containers/zen-builder/build-local.sh.
: "${ZEN_BUILDER_IMAGE:=zen-builder:local-test}"

# ovftool is not redistributable: kept on the host, bind-mounted below.
: "${OVFTOOL_HOST_DIR:=/usr/lib/vmware-ovftool}"

if [[ ! -e /dev/kvm ]]; then
  echo "ERROR: /dev/kvm not present -- the zen runner needs KVM exposed." >&2
  exit 1
fi

if [[ ! -x "${OVFTOOL_HOST_DIR}/ovftool" ]]; then
  echo "ERROR: ${OVFTOOL_HOST_DIR}/ovftool not found -- install VMware" >&2
  echo "ovftool on the host (or set OVFTOOL_HOST_DIR)." >&2
  exit 1
fi

# Open /dev/kvm via the device's gid instead of --privileged.
KVM_GID="$(stat -c '%g' /dev/kvm)"

echo "===> zen build in ${ZEN_BUILDER_IMAGE} (kvm gid=${KVM_GID}, build=${BUILD_NAME})"

# Runs as the calling user so bind-mounted files are not root-owned;
# HOME=/tmp keeps packer/ansible dotdirs writable.
docker run --rm \
  --pull always \
  --name "zen-build-${BUILD_NAME}" \
  --device /dev/kvm \
  --user "$(id -u):$(id -g)" \
  --group-add "${KVM_GID}" \
  -e HOME=/tmp \
  -e USER="$(id -un)" \
  -e PF_VERSION \
  -e PKR_VAR_pf_version \
  -e PKR_VAR_vm_name \
  -e PKR_ON_ERROR \
  -e VM_NAME \
  -e ANSIBLE_FORCE_COLOR \
  -e RCLONE_ACCESS_KEY_ID \
  -e RCLONE_SECRET_ACCESS_KEY \
  -e RCLONE_LINODE_URL \
  -v "${SCRIPT_DIR}":/zen \
  -v "${OVFTOOL_HOST_DIR}":/opt/vmware-ovftool:ro \
  -w /zen \
  "${ZEN_BUILDER_IMAGE}" \
  /zen/build-in-container.sh "${BUILD_NAME}"
