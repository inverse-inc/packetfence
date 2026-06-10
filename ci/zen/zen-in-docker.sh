#!/bin/bash
# Host-side wrapper invoked by `make zen-deb12`: runs the zen-builder
# image with /dev/kvm and hands off to build-in-container.sh.
set -o errexit -o nounset -o pipefail

BUILD_NAME="${1:?usage: zen-in-docker.sh <build-name> (e.g. debian-12)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CI sets the image ref; the default comes from containers/zen-builder/build-local.sh.
: "${ZEN_BUILDER_IMAGE:=zen-builder:local-test}"

# `always` matches the CI need for a fresh push; override to `never` locally.
: "${ZEN_BUILDER_PULL:=always}"

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

# Override docker's DNS for the qemu guest (space-separated).
DNS_ARGS=()
for ns in ${ZEN_BUILDER_DNS:-}; do DNS_ARGS+=(--dns "$ns"); done

echo "===> zen build in ${ZEN_BUILDER_IMAGE} (kvm gid=${KVM_GID}, build=${BUILD_NAME})"

# Pull up front so the passwd/group extraction below sees the same image as the main run.
if [[ "${ZEN_BUILDER_PULL}" == "always" ]]; then
  docker pull "${ZEN_BUILDER_IMAGE}"
fi

# Bind-mount a passwd/group with the host UID so ansible's getpwuid() works.
NSS_DIR="$(mktemp -d)"
trap 'rm -rf "${NSS_DIR}"' EXIT
docker run --rm --entrypoint cat "${ZEN_BUILDER_IMAGE}" /etc/passwd > "${NSS_DIR}/passwd"
docker run --rm --entrypoint cat "${ZEN_BUILDER_IMAGE}" /etc/group  > "${NSS_DIR}/group"
echo "builder:x:$(id -u):$(id -g):builder:/tmp:/bin/bash" >> "${NSS_DIR}/passwd"
echo "builder:x:$(id -g):"                                >> "${NSS_DIR}/group"

# Runs as the calling user so bind-mounted files are not root-owned;
# HOME=/tmp keeps packer/ansible dotdirs writable.
docker run --rm \
  --pull "${ZEN_BUILDER_PULL}" \
  --name "zen-build-${BUILD_NAME}" \
  "${DNS_ARGS[@]}" \
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
  -v "${NSS_DIR}/passwd":/etc/passwd:ro \
  -v "${NSS_DIR}/group":/etc/group:ro \
  -w /zen \
  "${ZEN_BUILDER_IMAGE}" \
  /zen/build-in-container.sh "${BUILD_NAME}"
