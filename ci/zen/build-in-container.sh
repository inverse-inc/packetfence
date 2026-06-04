#!/bin/bash
# Runs inside the zen-builder container (started by zen-in-docker.sh):
# packer qemu build, then qcow2 -> VMware OVA via build-and-upload.sh.
set -o errexit -o nounset -o pipefail

BUILD_NAME="${1:?usage: build-in-container.sh <build-name> (e.g. debian-12)}"

ZEN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ansible/paramiko needs getpwuid() to resolve the running UID.
if ! getent passwd "$(id -u)" >/dev/null; then
    echo "builder:x:$(id -u):$(id -g):builder:${HOME:-/tmp}:/bin/bash" >> /etc/passwd
fi
if ! getent group "$(id -g)" >/dev/null; then
    echo "builder:x:$(id -g):" >> /etc/group
fi

# ovftool is bind-mounted from the host; fail fast if the mount is broken.
echo "===> ovftool sanity check"
ovftool --version

# Absolute result dirs so packer (cwd packer/) and build-and-upload.sh agree.
export PKR_VAR_output_qemu_directory="${ZEN_DIR}/results/qemu"
export QEMU_RESULT_DIR="${PKR_VAR_output_qemu_directory}"
export VMWARE_RESULT_DIR="${ZEN_DIR}/results/vmware"

# packer's relative paths (files/, provisioners/, ansible.cfg) resolve here.
cd "${ZEN_DIR}/packer"

echo "===> packer init"
packer init .

echo "===> packer build qemu.${BUILD_NAME}"
packer build -only="qemu.${BUILD_NAME}" -on-error="${PKR_ON_ERROR:-cleanup}" .

cd "${ZEN_DIR}"

echo "===> convert qcow2 -> VMware OVA + upload"
./build-and-upload.sh
