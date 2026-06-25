#!/bin/bash
# Bake a vagrant box for a PacketFence VM by booting the upstream box, fully
# provisioning it via addons/vagrant/site.yml (scoped to the PF VM via -l),
# and running the Venom configurator scenario once. The resulting .box is
# published to Linode Object Storage (upload-to-linode.sh) and consumed by
# all downstream test jobs in the same pipeline (setup-vagrant-box.sh), so
# they skip site.yml and the configurator wizard.
#
# Required env: BAKE_ARCH (el8|deb12), PF_VM_NAME (pfel8dev|pfdeb12dev),
#               CI_PIPELINE_ID.
# Optional env: RESULT_DIR, VAGRANT_PF_DOTFILE_PATH.

set -o nounset -o pipefail -o errexit

VAGRANT_LIB_DIR=$(readlink -e "$(dirname "${BASH_SOURCE[0]}")")
PF_SRC_DIR=$(echo "${VAGRANT_LIB_DIR}" | grep -oP '.*?(?=\/ci\/)')

source "${PF_SRC_DIR}/ci/lib/common/functions.sh"

configure_and_check() {
    BAKE_ARCH=${BAKE_ARCH:?BAKE_ARCH must be set (e.g. el8, deb12)}
    PF_VM_NAME=${PF_VM_NAME:?PF_VM_NAME must be set (e.g. pfel8dev, pfdeb12dev)}
    CI_PIPELINE_ID=${CI_PIPELINE_ID:?CI_PIPELINE_ID must be set}

    RESULT_DIR=${RESULT_DIR:-/var/local/gitlab-runner/vagrant_img/${CI_PIPELINE_ID}}
    BOX_NAME="${PF_VM_NAME}"
    BOX_FILE="${RESULT_DIR}/${BOX_NAME}-libvirt.box"

    VAGRANT_PF_DOTFILE_PATH=${VAGRANT_PF_DOTFILE_PATH:-/var/local/gitlab-runner/vagrant/bake-${CI_PIPELINE_ID}-${BAKE_ARCH}}
    VAGRANT_DIR="${PF_SRC_DIR}/addons/vagrant"
    VENOM_DIR="${PF_SRC_DIR}/t/venom"

    # site.yml builds PPA URLs from pf_minor_release; without it the
    # inventory defaults to 99.9 and apt fails on a nonexistent repo.
    get_pf_release

    # Keep the job log under GitLab's 4MB cap: hide ok/skipped tasks and
    # deprecation warnings in every ansible run (failed/changed still print).
    export ANSIBLE_DISPLAY_OK_HOSTS=false
    export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false
    export ANSIBLE_DEPRECATION_WARNINGS=false

    declare -p BAKE_ARCH PF_VM_NAME CI_PIPELINE_ID
    declare -p RESULT_DIR BOX_NAME BOX_FILE VAGRANT_PF_DOTFILE_PATH
    declare -p VAGRANT_DIR VENOM_DIR PF_MINOR_RELEASE

    mkdir -p "${RESULT_DIR}"
}

# Delegate to test-wrapper.sh to boot the upstream box (Vagrant runs site.yml
# via its Ansible provisioner) and execute the configurator Venom scenario.
# Setting INT_TEST_VM_NAMES="" keeps the run PF-only.
provision_and_run_configurator() {
    log_section "Provision PF VM and run configurator scenario"
    # SITE_PROVISION_PLAYBOOK is intentionally unset: the default site.yml
    # invocation (scoped via Vagrant's -l to the PF VM) runs site_pf.yml
    # plays plus utils.yml; site_others.yml plays no-op for the PF VM since
    # no matching hosts are in scope.
    ( cd "${VENOM_DIR}" \
        && PF_VM_NAMES="${PF_VM_NAME}" \
           INT_TEST_VM_NAMES="" \
           SCENARIOS_TO_RUN="configurator" \
           PF_MINOR_RELEASE="${PF_MINOR_RELEASE}" \
           VAGRANT_PF_DOTFILE_PATH="${VAGRANT_PF_DOTFILE_PATH}" \
           ./test-wrapper.sh run )
}

# Drop RHEL entitlement certs (/etc/pki/consumer, /var/lib/rhsm) before
# packaging. No-op on Debian via the playbook's own ansible_os_family guard.
unregister_pf_vm() {
    log_section "Unregister RHEL subscription on ${PF_VM_NAME} (pre-sysprep)"
    ( cd "${VAGRANT_DIR}" \
        && ansible-playbook playbooks/unregister_rhel_subscription.yml \
               -l "${PF_VM_NAME}" )
}

# Run sysprep_pf.yml inside the live PF VM right before halt, so the
# packaged box ships with empty machine-id, no NM connection state, no
# stale SSH host keys, etc. Replaces the previous virt-sysprep-in-a-
# container step (which kept tripping over libguestfs/supermin on certain
# runners, e.g. cloud-12, with no readable kernel / no nested KVM).
sysprep_pf_vm() {
    log_section "Sysprep PF VM ${PF_VM_NAME} (in-guest, pre-halt)"
    ( cd "${VAGRANT_DIR}" \
        && ansible-playbook playbooks/sysprep_pf.yml -l "${PF_VM_NAME}" )
}

halt_pf_vm() {
    log_section "Halt PF VM ${PF_VM_NAME}"
    ( cd "${VAGRANT_DIR}" \
        && VAGRANT_DOTFILE_PATH="${VAGRANT_PF_DOTFILE_PATH}" \
           vagrant halt "${PF_VM_NAME}" )
}

# Packaging needs the VM stopped. `vagrant package` is avoided on purpose:
# it downloads the full 130G logical volume then gzips it (~30+ min of
# bsdtar and a log full of Progress lines). qemu-img convert reads only the
# allocated clusters, flattens the backing chain and writes a compressed
# qcow2, which is then tarred into the .box vagrant layout. RESULT_DIR is
# local staging only: the .box is uploaded to Linode Object Storage at
# packetfence-vagrant-box/ci/<category>/<BOX_NAME>_<CI_PIPELINE_ID>.box where
# test runners fetch it via setup-vagrant-box.sh. cleanup-old-vagrant-boxes.sh
# sweeps ci/branches/ before each upload; devel/maintenance bakes are kept
# indefinitely.
#
# qemu-img convert runs inside a container because the libvirt default
# pool is root-owned and the gitlab-runner user can't read the volume
# directly. The pool dir is bind-mounted at its original path so the
# absolute backing_file reference baked into the overlay still resolves.
# Container is plain qemu-utils — no libguestfs/supermin, no /dev/kvm.
# Sysprep is done in-guest before halt (see sysprep_pf_vm above).
convert_box_volume() {
    log_section "Convert ${PF_VM_NAME} volume to compressed qcow2"
    rm -f "${BOX_FILE}"
    mkdir -p "${RESULT_DIR}"

    local machine_uuid vol_path vol_dir
    machine_uuid=$(cat "${VAGRANT_PF_DOTFILE_PATH}/machines/${PF_VM_NAME}/libvirt/id")
    vol_path=$(virsh -c qemu:///system domblklist "${machine_uuid}" | awk '$1 == "vda" { print $2 }')
    vol_dir=$(dirname "${vol_path}")
    echo "Converting volume ${vol_path}"

    BOX_STAGING_DIR=$(mktemp -d -p "${RESULT_DIR}")
    docker run --rm \
        -v "${vol_dir}:${vol_dir}:ro" \
        -v "${BOX_STAGING_DIR}:/out" \
        debian:bookworm-slim \
        sh -c "export DEBIAN_FRONTEND=noninteractive \
            && apt-get update -qq \
            && apt-get install -qq -y --no-install-recommends qemu-utils >/dev/null \
            && qemu-img convert -O qcow2 -c -o compression_type=zstd -m 16 -W '${vol_path}' /out/box.img \
            && chown $(id -u):$(id -g) /out/box.img"
}

# Drop the prefetched base box from the vagrant cache once the converted
# qcow2 is in BOX_STAGING_DIR. Frees several GB on the runner's
# .vagrant.d/RESULT_DIR filesystem before the tar step (which momentarily
# holds box.img twice: once in staging, once written into the .box).
# `vagrant box remove` leaves the libvirt pool volume behind, so sweep it too.
cleanup_base_box() {
    log_section "Remove cached base box from .vagrant.d and libvirt pool"
    local base_box="inverse-inc/${PF_VM_NAME/dev/branch}"
    if vagrant box list 2>/dev/null | grep -qE "^${base_box}\b"; then
        vagrant box remove --force --all --provider libvirt "${base_box}" || true
    fi

    # vagrant-libvirt mangles "inverse-inc/foo" → "inverse-inc-VAGRANTSLASH-foo"
    local slug="${base_box//\//-VAGRANTSLASH-}"
    local pool_vols vol
    pool_vols=$(virsh -c qemu:///system vol-list default 2>/dev/null \
        | awk -v p="${slug}_vagrant_box_image_" '$1 ~ p { print $1 }' || true)
    if [ -n "${pool_vols}" ]; then
        echo "${pool_vols}" | sed 's/^/  pool vol: /'
        for vol in ${pool_vols}; do
            virsh -c qemu:///system vol-delete --pool default "${vol}" || true
        done
    fi
}

# Tar the converted box.img + vagrant metadata into BOX_FILE. Run AFTER
# convert_box_volume + destroy_pf_vm + cleanup_base_box so the runner fs
# has room for the duplicated box.img during the tar write.
package_box() {
    log_section "Package box to ${BOX_FILE}"

    local virtual_size_b virtual_size_g
    virtual_size_b=$(qemu-img info --output=json "${BOX_STAGING_DIR}/box.img" \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["virtual-size"])')
    virtual_size_g=$(( (virtual_size_b + (1 << 30) - 1) >> 30 ))

    cat > "${BOX_STAGING_DIR}/metadata.json" <<EOF
{
  "provider": "libvirt",
  "format": "qcow2",
  "virtual_size": ${virtual_size_g}
}
EOF
    cat > "${BOX_STAGING_DIR}/Vagrantfile" <<'EOF'
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "kvm"
  end
end
EOF

    # box.img is already compressed: plain tar, vagrant box add auto-detects
    tar -C "${BOX_STAGING_DIR}" -cf "${BOX_FILE}" ./metadata.json ./Vagrantfile ./box.img
    rm -rf "${BOX_STAGING_DIR}"
    ls -lh "${BOX_FILE}"
}

cleanup_old_boxes_remote() {
    log_section "Cleanup old pipeline-baked boxes from Linode (>3 days)"
    "${VAGRANT_LIB_DIR}/cleanup-old-vagrant-boxes.sh" \
        || echo "WARNING: remote cleanup failed (non-fatal)"
}

upload_box() {
    log_section "Upload box to Linode Object Storage"
    BOX_NAME="${BOX_NAME}" RESULT_DIR="${RESULT_DIR}" \
        "${VAGRANT_LIB_DIR}/upload-to-linode.sh"
}

cleanup_local_box() {
    log_section "Remove local box (uploaded copy is authoritative)"
    rm -rf "${RESULT_DIR}"
}

destroy_pf_vm() {
    log_section "Destroy PF VM and remove dotfile path"
    ( cd "${VAGRANT_DIR}" \
        && VAGRANT_DOTFILE_PATH="${VAGRANT_PF_DOTFILE_PATH}" \
           vagrant destroy -f "${PF_VM_NAME}" || true )
    if [ -d "${VAGRANT_PF_DOTFILE_PATH}" ]; then
        rm -rf "${VAGRANT_PF_DOTFILE_PATH}"
    fi
}

run() {
    provision_and_run_configurator
    unregister_pf_vm
    sysprep_pf_vm
    halt_pf_vm
    convert_box_volume
    destroy_pf_vm
    cleanup_base_box
    package_box
    cleanup_old_boxes_remote
    upload_box
    cleanup_local_box
}

# Best-effort cleanup used as after_script when the main run aborts mid-flight.
teardown() {
    log_section "Teardown (best-effort cleanup)"
    destroy_pf_vm
    cleanup_base_box
    rm -rf "${RESULT_DIR}"
}

configure_and_check

case ${1:-run} in
    run)      run ;;
    teardown) teardown ;;
    *)        die "Unknown argument: $1 (expected: run|teardown)" ;;
esac
