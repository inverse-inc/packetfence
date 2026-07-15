#!/bin/bash
set -o nounset -o pipefail -o errexit

die() {
    echo "$(basename $0): $@" >&2 ; exit 1
}

log_section() {
   printf '=%.0s' {1..72} ; printf "\n"
   printf "=\t%s\n" "" "$@" ""
}

log_subsection() {
   printf "=\t%s\n" "" "$@" ""
}

# timestamped wall-clock per phase, so slow bring-up stages show in the log
time_phase() {
    local label=$1; shift
    local start=$(date +%s)
    echo "[$(date '+%F %T')] ${label}: start"
    "$@"
    local secs=$(( $(date +%s) - start ))
    echo "[$(date '+%F %T')] ${label}: done in $((secs/60))m$((secs%60))s"
}

# vagrant redraws "Progress: N%" with carriage returns (no newline), so the whole
# burst arrives as one line; `tr` splits it so each redraw can be dropped. Covers
# the vagrant-libvirt volume upload ("Progress: 0%") and box downloads
# ("name: Progress: 45% (Rate: ...)"). Real output, including colors, passes through.
filter_vagrant_progress() {
    local esc=$'\033'
    tr '\r' '\n' | awk -v esc="$esc" '
      { clean = $0; gsub(esc "\\[[0-9;]*[A-Za-z]", "", clean) }
      clean ~ /^[ \t]*([A-Za-z0-9._-]+: )?Progress: [0-9]+%([ \t]*\(.*\))?[ \t]*$/ { next }   # drop progress redraws
      clean ~ /^[ \t]*$/ && $0 != clean { next }                                              # drop control-only fragments
      { print; fflush() }
    '
}

delete_dir_if_exists() {
    local dir=${1}
    if [ -d "${dir}" ]; then
        rm -r ${dir}
        echo "Directory ${dir} removed"
    else
        echo "No ${dir} directory to remove"
    fi
}

configure_and_check() {
    log_section "Configure and check"
    # full path to root of sources
    RESULT_DIR=${RESULT_DIR:-}
    VENOM_ROOT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))
    SCENARIOS_BASE_DIR=${VENOM_ROOT_DIR}/scenarios
    SCENARIOS_TO_RUN=${SCENARIOS_TO_RUN:-foo bar}
    PF_VM_NAMES=${PF_VM_NAMES:-}
    CLUSTER_NAME=${CLUSTER_NAME:-}
    INT_TEST_VM_NAMES=${INT_TEST_VM_NAMES:-}
    DESTROY_ALL=${DESTROY_ALL:-no}

    if [ -n "${INT_TEST_VM_NAMES}" ]; then
	ALL_VM_NAMES="${PF_VM_NAMES} ${INT_TEST_VM_NAMES}"
    else
	ALL_VM_NAMES="${PF_VM_NAMES}"
    fi
    # replace spaces by commas
    ANSIBLE_VM_LIST=${ALL_VM_NAMES// /,}

    # Vagrant
    VAGRANT_FORCE_COLOR=${VAGRANT_FORCE_COLOR:-true}
    VAGRANT_ANSIBLE_VERBOSE=${VAGRANT_ANSIBLE_VERBOSE:-false}
    # serial boots: parallel volume imports thrash the runner's disk
    VAGRANT_UP_OPTS=${VAGRANT_UP_OPTS:-'--no-destroy-on-error --no-parallel'}
    VAGRANT_DIR=$(readlink -e ../../addons/vagrant)
    VAGRANT_PF_DOTFILE_PATH="${VAGRANT_PF_DOTFILE_PATH:-${VAGRANT_DIR}/.vagrant}"
    VAGRANT_COMMON_DOTFILE_PATH="${VAGRANT_COMMON_DOTFILE_PATH:-${VAGRANT_DIR}/.vagrant}"

    # Ansible configs
    ANSIBLE_INVENTORY="${VAGRANT_DIR}/inventory"

    CI_COMMIT_TAG=${CI_COMMIT_TAG:-}
    CI_PIPELINE_ID=${CI_PIPELINE_ID:-}
    PF_MINOR_RELEASE=${PF_MINOR_RELEASE:-}

    # Baked vagrant box (set by bake_img_vagrant_* CI jobs). When
    # USE_VAGRANT_BOX=yes, PF VMs (pfel8dev/pfdeb12dev) boot from the
    # per-pipeline pre-baked box inverse-inc/<vm> registered by
    # ci/lib/vagrant/setup-vagrant-box.sh, skipping site.yml and the
    # configurator wizard. Defaults preserve the original behavior.
    USE_VAGRANT_BOX=${USE_VAGRANT_BOX:-no}
    VAGRANT_BOX_VERSION=${VAGRANT_BOX_VERSION:-}
    SKIP_CONFIGURATOR_BAKED=${SKIP_CONFIGURATOR_BAKED:-no}
    FALLBACK_TO_FULL_PROVISION=${FALLBACK_TO_FULL_PROVISION:-no}
    SETUP_VAGRANT_BOX_SCRIPT="${VENOM_ROOT_DIR}/../../ci/lib/vagrant/setup-vagrant-box.sh"

    declare -p VAGRANT_DIR VAGRANT_ANSIBLE_VERBOSE VAGRANT_PF_DOTFILE_PATH VAGRANT_COMMON_DOTFILE_PATH
    declare -p ANSIBLE_INVENTORY RESULT_DIR VENOM_ROOT_DIR
    declare -p CI_COMMIT_TAG CI_PIPELINE_ID PF_MINOR_RELEASE
    declare -p PF_VM_NAMES CLUSTER_NAME INT_TEST_VM_NAMES ALL_VM_NAMES ANSIBLE_VM_LIST
    declare -p SCENARIOS_TO_RUN DESTROY_ALL
    declare -p USE_VAGRANT_BOX VAGRANT_BOX_VERSION
    declare -p SKIP_CONFIGURATOR_BAKED FALLBACK_TO_FULL_PROVISION

    export ANSIBLE_INVENTORY
    export VENOM_ROOT_DIR
    export USE_VAGRANT_BOX VAGRANT_BOX_VERSION
    export SKIP_CONFIGURATOR_BAKED
}

# PF VMs eligible for the per-pipeline baked box (echoes the VM name, "" if
# not eligible). Kept in sync with baked_box_vms in pfservers/Vagrantfile.
baked_box_for_pf_vm() {
    case "$1" in
        pfel8dev|pfdeb12dev) echo "$1" ;;
        *)                   echo "" ;;
    esac
}

maybe_fallback_to_full_provision() {
    local reason=$1
    if [ "${FALLBACK_TO_FULL_PROVISION}" = "yes" ]; then
        echo "FALLBACK_TO_FULL_PROVISION=yes — falling back to full site.yml provisioning (reason: ${reason})"
        USE_VAGRANT_BOX=no
        export USE_VAGRANT_BOX
        return 0
    fi
    die "Cannot use baked vagrant box: ${reason}. Set FALLBACK_TO_FULL_PROVISION=yes to fall back to site.yml."
}

# The baked box is normally registered by ci/lib/vagrant/setup-vagrant-box.sh
# in the CI job's before_script; verify it is present and (re-)run the setup
# script when it is not (e.g. local runs outside CI).
register_vagrant_box_or_fallback() {
    local vm=$1
    local box=$(baked_box_for_pf_vm "${vm}")
    [ -n "${box}" ] || return 0

    if [ -z "${VAGRANT_BOX_VERSION}" ]; then
        maybe_fallback_to_full_provision "VAGRANT_BOX_VERSION is empty"
        return $?
    fi

    local box_name="inverse-inc/${box}"

    if vagrant box list | grep -qF "${box_name} (libvirt, ${VAGRANT_BOX_VERSION})"; then
        log_subsection "Box ${box_name} v${VAGRANT_BOX_VERSION} already registered"
        return 0
    fi

    log_subsection "Register box ${box_name} v${VAGRANT_BOX_VERSION}"
    if ! BOX_NAME="${box}" VAGRANT_BOX_VERSION="${VAGRANT_BOX_VERSION}" "${SETUP_VAGRANT_BOX_SCRIPT}"; then
        maybe_fallback_to_full_provision "setup-vagrant-box.sh failed for ${box_name}"
        return $?
    fi
}

# After a baked-box `vagrant up`, libvirt assigns fresh MACs so the PF
# interface→IP bindings baked at configurator time may need re-applying.
refresh_network_post_import() {
    local vm=$1
    log_subsection "Refresh network on ${vm} (post-import boot)"
    ( cd ${VAGRANT_DIR} ; \
      ansible-playbook playbooks/refresh_network_post_import.yml -l "${vm}" )
}

# The bake unregisters RHEL before packaging, so a baked el8 clone boots
# without yum repos; re-register so scenarios can install packages.
# No-op on Debian (playbook guards on os_family); teardown unregisters.
reregister_rhel_post_import() {
    local vm=$1
    log_subsection "Re-register RHEL subscription on ${vm} (post-import)"
    ( cd ${VAGRANT_DIR} ; \
      ansible-playbook playbooks/register_rhel_subscription.yml -l "${vm}" )
}

check_free_space() {
    # https://www.gnu.org/software/coreutils/manual/html_node/Block-size.html
    # "the block size currently defaults to 1024 bytes"
    # 30GiB (1,073,741,824 * 30 ) = 32,212,254,720
    # size necessary to run a full test with pf*dev, switch, ad, wireless and node0*
    # it's a bit over than necessary because ad, switch and wireless could have been
    # already provisioned
    MANDATORY_SPACE='32212254'
    AVAILABLE_SPACE=$(df --total -x tmpfs -x vfat -x devtmpfs --output=avail | tail -n 1)

    # Low on space: reclaim from old/unused images, then re-measure.
    if (( AVAILABLE_SPACE <= MANDATORY_SPACE )); then
        reclaim_disk_space
        AVAILABLE_SPACE=$(df --total -x tmpfs -x vfat -x devtmpfs --output=avail | tail -n 1)
    fi

    if ((  $AVAILABLE_SPACE > $MANDATORY_SPACE )); then
        echo "Enough space on system to run tests."
    else
        die "There is not enough space on system to run tests, even after cleanup. Skipping tests."
    fi
}

# Reclaim disk on low space. Only touches things not in use (concurrent jobs
# stay safe); does not delete /var/lib/libvirt/images base volumes.
reclaim_disk_space() {
    log_subsection "Low disk space: reclaiming from old/unused images"
    local vm

    for vm in $(virsh list --inactive --name); do
        echo "Undefining shut-off VM: $vm"
        virsh undefine "$vm" --remove-all-storage || true
    done
    for vm in $(virsh list --name --state-paused); do
        echo "Destroying paused VM: $vm"
        virsh destroy "$vm" && virsh undefine "$vm" --remove-all-storage || true
    done

    ( cd "${VAGRANT_DIR}" && vagrant box prune --force ) || true

    local cache="${VAGRANT_IMG_CACHE:-${HOME}/vagrant_img_cache}"
    if [ -d "${cache}" ]; then
        find "${cache}" -maxdepth 1 -type f \( -name '*.box' -o -name '*.box.md5sums.txt' \) \
             -atime +3 -print -delete || true
    fi
}

run_ansible_galaxy() {
    local req_file=${1:-}
    local force=${2:-}
    if [ -z "$force" ]; then
        local ansible_cmd="ansible-galaxy install -r ${req_file}"
    else
        local ansible_cmd="ansible-galaxy install -r ${req_file} --force"
    fi
    for retry in {5..1}; do
        if ${ansible_cmd}; then
            break
        elif [ $retry -gt 1 ]; then
            sleep 10
        else
            exit 1
        fi
    done
}

# force-install each requirements file once per run instead of once per VM
declare -A GALAXY_DONE
run_ansible_galaxy_once() {
    local req_file=$1
    if [ -z "${GALAXY_DONE[${req_file}]:-}" ]; then
        # cd first: collections/roles paths in the local ansible.cfg are relative to CWD
        ( cd $(dirname ${req_file}) ; run_ansible_galaxy ${req_file} force )
        GALAXY_DONE[${req_file}]=1
    fi
}

run() {
    local run_start=$(date +%s)
    check_free_space
    log_section "Tests"
    time_phase "Start and provision PF VMs" start_and_provision_pf_vm ${PF_VM_NAMES}
    if [ -n "${INT_TEST_VM_NAMES}" ]; then
        time_phase "Start and provision other VMs" start_and_provision_other_vm ${INT_TEST_VM_NAMES}
    else
        log_subsection "No additional VM to start and provision"
    fi
    time_phase "Run scenarios: ${SCENARIOS_TO_RUN}" run_tests
    local total=$(( $(date +%s) - run_start ))
    log_section "Full run took $((total/60))m$((total%60))s"
}

# Inventory's box_url for the private bucket (packetfence-vagrant-box) is not
# fetchable over anonymous HTTPS (403); pre-register the box via authenticated
# rclone so vagrant never tries the public URL. Public boxes (generic/*,
# debian/*) have no bucket URL and are left for vagrant to handle.
prefetch_private_box() {
    local vm=$1
    local prefetch_script="${VENOM_ROOT_DIR}/../../ci/lib/vagrant/prefetch-base-box.sh"
    [ -x "${prefetch_script}" ] || return 0

    local box_info
    box_info=$(python3 - "${ANSIBLE_INVENTORY}/hosts" "${vm}" <<'PY' 2>/dev/null || true
import sys, yaml
inv = yaml.safe_load(open(sys.argv[1]))
target, hit = sys.argv[2], {}
def walk(node):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == target and isinstance(v, dict) and 'box' in v:
                hit.update(v)
            walk(v)
    elif isinstance(node, list):
        for x in node:
            walk(x)
walk(inv)
print(hit.get('box_url', ''))
print(hit.get('box_version', ''))
PY
)
    local box_url box_version
    box_url=$(echo "${box_info}" | sed -n 1p)
    box_version=$(echo "${box_info}" | sed -n 2p)

    case "${box_url}" in
        *packetfence-vagrant-box*) ;;
        *) return 0 ;;
    esac

    # Private box: rclone creds are mandatory. Fail clearly instead of letting
    # vagrant emit an opaque "metadata fetch ... 403".
    [ -n "${RCLONE_ACCESS_KEY_ID:-}" ] || die \
        "VM '${vm}' needs private box '${box_url}' but RCLONE_ACCESS_KEY_ID is unset (set RCLONE_ACCESS_KEY_ID/RCLONE_SECRET_ACCESS_KEY/RCLONE_LINODE_URL)."

    # https://<host>/<box_name>/metadata.json -> <box_name>
    local box_name
    box_name=$(basename "$(dirname "${box_url}")")
    log_subsection "Pre-fetching private box '${box_name}'${box_version:+ v${box_version}} for VM '${vm}'"
    BOX_NAME="${box_name}" BOX_VERSION="${box_version}" "${prefetch_script}" \
        || die "failed to fetch box ${box_name} for ${vm}"
}

# start via libvirt without waiting; callers poll readiness with wait_for_ssh
start_existing_vm() {
    local vm=$1
    local dotfile_path=$2
    local machine_uuid machine_state
    machine_uuid=$(cat "${dotfile_path}/machines/${vm}/libvirt/id")
    machine_state=$(virsh -c qemu:///system domstate --domain "${machine_uuid}")
    if [ "${machine_state}" = "shut off" ]; then
        echo "Starting ${vm} using libvirt"
        virsh -c qemu:///system start --domain "${machine_uuid}"
    else
        echo "Machine already started"
    fi
}

# wait for SSH and default route (mgmt SSH answers before eth0 DHCP is done)
wait_for_ssh() {
    local vm_list=${1// /,}
    ( cd ${VAGRANT_DIR} ; \
      ansible -m wait_for_connection -a "timeout=300" ${vm_list} ; \
      ansible -m shell -a "timeout 120 bash -c 'until ip -4 route list default | grep -q .; do sleep 2; done'" ${vm_list} )
}

# Start with or without VM
start_vm() {
    local vm=$1
    local dotfile_path=$2
    declare -p dotfile_path

    # baked is non-empty only for baked-box-eligible PF VMs in baked-box mode
    local baked=""
    if [ "${USE_VAGRANT_BOX}" = "yes" ]; then
        baked=$(baked_box_for_pf_vm "${vm}")
    fi

    if [ -e "${dotfile_path}/machines/${vm}/libvirt/id" ]; then
        echo "Machine $vm already exists"
        machine_uuid=$(cat ${dotfile_path}/machines/${vm}/libvirt/id)
        machine_state=$(virsh -c qemu:///system domstate --domain $machine_uuid)
        if [ "${machine_state}" = "shut off" ]; then
            echo "Starting $vm using libvirt, provisioning using Ansible (without Vagrant)"
            virsh -c qemu:///system start --domain $machine_uuid
            # let time for the VM to boot before using ansible
            echo "Let time to VM to start before provisioning using Ansible.."
            sleep 60
        else
            echo "Machine already started, Ansible provisioning only"
        fi
        if [ -n "${baked}" ]; then
            # Baked-box mode: PF VM is already fully provisioned + configured.
            # Re-running site.yml would undo the bake, so only refresh network.
            ( cd ${VAGRANT_DIR}; \
              run_ansible_galaxy ${VAGRANT_DIR}/requirements.yml force )
            refresh_network_post_import "${vm}"
            reregister_rhel_post_import "${vm}"
        else
            ( cd ${VAGRANT_DIR}; \
              run_ansible_galaxy ${VAGRANT_DIR}/requirements.yml force ; \
              ansible-playbook site.yml -l $vm )
        fi
    else
        echo "Machine $vm doesn't exist, start and provision with Vagrant"
        if [ -n "${baked}" ]; then
            register_vagrant_box_or_fallback "${vm}"
            # register_vagrant_box_or_fallback may have flipped USE_VAGRANT_BOX
            # to "no" via the fallback path; recompute baked to honor it.
            baked=""
            [ "${USE_VAGRANT_BOX}" = "yes" ] && baked=$(baked_box_for_pf_vm "${vm}")
        fi
        # Baked artifact replaces the base box — skip prefetch in baked mode.
        if [ -z "${baked}" ]; then
            prefetch_private_box "${vm}"
        fi
        if [ -n "${baked}" ]; then
            ( cd ${VAGRANT_DIR} ; \
              run_ansible_galaxy ${VAGRANT_DIR}/requirements.yml force ; \
              SKIP_SITE_PROVISION=yes \
              VAGRANT_DOTFILE_PATH=${dotfile_path} \
                      vagrant up \
                      ${vm} \
                      ${VAGRANT_UP_OPTS} ) 2>&1 | filter_vagrant_progress
            refresh_network_post_import "${vm}"
            reregister_rhel_post_import "${vm}"
        else
            ( cd ${VAGRANT_DIR} ; \
              run_ansible_galaxy ${VAGRANT_DIR}/requirements.yml force ; \
              VAGRANT_DOTFILE_PATH=${dotfile_path} \
                      vagrant up \
                      ${vm} \
                      ${VAGRANT_UP_OPTS} ) 2>&1 | filter_vagrant_progress
        fi
    fi
}

start_and_provision_pf_vm() {
    local vm_names=${@:-vmname}
    log_subsection "Start and provision PacketFence $vm_names"
    run_ansible_galaxy_once ${VAGRANT_DIR}/requirements.yml
    # Baked-box mode boots each PF VM from its pre-baked image and only
    # refreshes the network (no site.yml), so it can't share the parallel
    # provision path below — start_vm handles the baked flow per VM.
    if [ "${USE_VAGRANT_BOX}" = "yes" ]; then
        for vm in ${vm_names}; do
            start_vm ${vm} ${VAGRANT_PF_DOTFILE_PATH}
        done
        return
    fi
    # boot all nodes first (one parallel vagrant up for the missing ones), then
    # wait for SSH on all and install PacketFence in a single ansible run
    local new_vms=""
    for vm in ${vm_names}; do
        if [ -e "${VAGRANT_PF_DOTFILE_PATH}/machines/${vm}/libvirt/id" ]; then
            echo "Machine $vm already exists"
            start_existing_vm ${vm} ${VAGRANT_PF_DOTFILE_PATH}
        else
            echo "Machine $vm doesn't exist, will start with Vagrant"
            prefetch_private_box ${vm}
            new_vms="${new_vms} ${vm}"
        fi
    done
    if [ -n "${new_vms}" ]; then
        ( cd ${VAGRANT_DIR} ; \
          VAGRANT_DOTFILE_PATH=${VAGRANT_PF_DOTFILE_PATH} \
                  vagrant up \
                  ${new_vms} \
                  ${VAGRANT_UP_OPTS} --no-provision 2>&1 | filter_vagrant_progress )
    fi
    log_subsection "Wait for SSH on: $vm_names"
    wait_for_ssh "${vm_names}"
    local ansible_list=${vm_names// /,}
    log_subsection "Install PacketFence in parallel on: $vm_names"
    ( cd ${VAGRANT_DIR} ; \
      ansible-playbook site.yml -l "${ansible_list}" )
}

start_and_provision_other_vm() {
    local vm_names=${@:-vmname}
    log_subsection "Start and provision $vm_names"

    for vm in ${vm_names}; do
        if [ "$vm" = "node01" ] || [ "$vm" = "node03" ]; then
            start_vm ${vm} ${VAGRANT_PF_DOTFILE_PATH}
        else
            start_vm ${vm} ${VAGRANT_COMMON_DOTFILE_PATH}
        fi
    done
}

run_tests() {
    log_subsection "Configure VM for tests and run tests"
    # install roles and collections in VENOM_ROOT_DIR
    run_ansible_galaxy_once ${VENOM_ROOT_DIR}/requirements.yml

    for scenario_name in ${SCENARIOS_TO_RUN}; do
        scenario_path="${SCENARIOS_BASE_DIR}/${scenario_name}"
        if [ -e "${scenario_path}/ansible_inventory.yml" ]; then
            echo "Additional Ansible inventory detected, will use it"
            # will find roles and collections in VENOM_ROOT_DIR
            ansible-playbook ${scenario_path}/site.yml -l $ANSIBLE_VM_LIST -e "@${scenario_path}/ansible_inventory.yml"
        else
            ansible-playbook ${scenario_path}/site.yml -l $ANSIBLE_VM_LIST
        fi
    done
}

teardown() {
    log_section "Teardown"
    ansible_teardown
    delete_ansible_files
}

ansible_teardown() {
    log_subsection "Ansible teardown (RHEL8 Unregister and Get Logs on all VM)"
    if [ -n "${ANSIBLE_VM_LIST}" ]; then
        ( cd $VAGRANT_DIR ; \
          ansible-playbook teardown.yml -l $ANSIBLE_VM_LIST )
    else
        echo "No VM detected, nothing to unconfigure"
    fi
}

delete_ansible_files() {
    log_subsection "Remove Ansible files"
    delete_dir_if_exists ${VAGRANT_DIR}/roles
    delete_dir_if_exists ${VAGRANT_DIR}/ansible_collections
    delete_dir_if_exists ${VENOM_ROOT_DIR}/roles
    delete_dir_if_exists ${VENOM_ROOT_DIR}/ansible_collections
}

# Cleaning = no test VMs, no leftover disk. vagrant destroy misses orphans
# (dotfile-only; DOMAIN_PREFIX's random hex never reclaims them), so sweep
# libvirt directly, scoped to the Vagrantfile prefix. Networks are shared/reused.
destroy() {
    log_section "Destroy virtual machines"
    local prefix="vagrant-${CI_COMMIT_REF_SLUG-${USER}}-"
    local vm pool vol
    for vm in $(virsh list --all --name | grep -F "${prefix}" || true); do
        echo "Destroying ${vm} and its disk"
        virsh destroy "${vm}" >/dev/null 2>&1 || true
        virsh undefine "${vm}" --remove-all-storage || true
    done
    # volumes orphaned by an interrupted run (domain gone, disk left behind)
    for pool in $(virsh pool-list --name 2>/dev/null || true); do
        for vol in $(virsh vol-list --pool "${pool}" 2>/dev/null | awk 'NR>2 && $1 {print $1}' | grep -F "${prefix}" || true); do
            echo "Deleting orphaned volume ${vol} (pool ${pool})"
            virsh vol-delete --pool "${pool}" "${vol}" || true
        done
    done
    # Backstop: catch PF + node VMs the prefix sweep missed (domain name not
    # matching the prefix), by UUID from this job's dotfiles, before those
    # dotfiles are deleted below.
    purge_job_domains
    cleanup_baked_boxes
    delete_dir_if_exists "${VAGRANT_PF_DOTFILE_PATH}"
    delete_dir_if_exists "${VAGRANT_COMMON_DOTFILE_PATH}"
    delete_ansible_files
}

# vagrant destroy only removes VMs it still tracks; one left by a failed `up`
# (--no-destroy-on-error) or an out-of-sync index survives it. Force-remove
# every domain recorded under this job's dotfile paths, with its storage —
# scoped by the UUIDs vagrant wrote, so parallel jobs on the runner are safe.
purge_job_domains() {
    log_subsection "Force-remove leftover domains tracked by this job"
    local dotfile id_file uuid
    for dotfile in "${VAGRANT_PF_DOTFILE_PATH}" "${VAGRANT_COMMON_DOTFILE_PATH}"; do
        [ -d "${dotfile}/machines" ] || continue
        while IFS= read -r id_file; do
            uuid=$(cat "${id_file}" 2>/dev/null) || continue
            [ -n "${uuid}" ] || continue
            virsh domstate "${uuid}" >/dev/null 2>&1 || continue
            echo "Removing leftover domain ${uuid} (${id_file})"
            virsh destroy "${uuid}" || true
            virsh undefine "${uuid}" --remove-all-storage --nvram || true
        done < <(find "${dotfile}/machines" -type f -path '*/libvirt/id' 2>/dev/null)
    done
}

# Drop this pipeline's baked vagrant-box record (~5GB in ~/.vagrant.d/boxes/)
# once its VMs are destroyed. The matching libvirt-pool backing is left
# for the admin sweep — parallel jobs in this pipeline still reference it.
cleanup_baked_boxes() {
    [ "${USE_VAGRANT_BOX}" = "yes" ] || return 0
    [ -n "${VAGRANT_BOX_VERSION}" ] || return 0
    log_subsection "Remove this pipeline's baked vagrant boxes"
    local category vm box box_name
    source "${VENOM_ROOT_DIR}/../../ci/lib/vagrant/box-category.sh"
    category=$(vagrant_box_category)
    for vm in ${PF_VM_NAMES}; do
        box=$(baked_box_for_pf_vm "${vm}")
        [ -n "${box}" ] || continue
        box_name="inverse-inc/${box}-${category}"
        echo "Removing ${box_name} v${VAGRANT_BOX_VERSION}"
        vagrant box remove --force --provider libvirt \
            --box-version "${VAGRANT_BOX_VERSION}" "${box_name}" || true
    done
}

configure_and_check

case $1 in
    run) run ;;
    run_tests) time_phase "Run scenarios: ${SCENARIOS_TO_RUN}" run_tests ;;
    destroy) destroy ;;
    teardown) teardown ;;
    *) die "Wrong argument"
esac
