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

delete_dir_if_exists() {
    local dir=${1}
    if [ -d "${dir}" ]; then
        rm -r ${dir}
        echo "Directory ${dir} removed"
    else
        echo "No ${dir} directory to remove"
    fi
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
    VAGRANT_UP_OPTS=${VAGRANT_UP_OPTS:-'--no-destroy-on-error --no-parallel'}
    VAGRANT_DIR=$(readlink -e ../../addons/vagrant)
    VAGRANT_PF_DOTFILE_PATH="${VAGRANT_PF_DOTFILE_PATH:-${VAGRANT_DIR}/.vagrant}"
    VAGRANT_COMMON_DOTFILE_PATH="${VAGRANT_COMMON_DOTFILE_PATH:-${VAGRANT_DIR}/.vagrant}"

    # Ansible configs
    ANSIBLE_INVENTORY="${VAGRANT_DIR}/inventory"

    CI_COMMIT_TAG=${CI_COMMIT_TAG:-}
    CI_PIPELINE_ID=${CI_PIPELINE_ID:-}
    PF_MINOR_RELEASE=${PF_MINOR_RELEASE:-}

    declare -p VAGRANT_DIR VAGRANT_ANSIBLE_VERBOSE VAGRANT_PF_DOTFILE_PATH VAGRANT_COMMON_DOTFILE_PATH
    declare -p ANSIBLE_INVENTORY RESULT_DIR VENOM_ROOT_DIR
    declare -p CI_COMMIT_TAG CI_PIPELINE_ID PF_MINOR_RELEASE
    declare -p PF_VM_NAMES CLUSTER_NAME INT_TEST_VM_NAMES ALL_VM_NAMES ANSIBLE_VM_LIST
    declare -p SCENARIOS_TO_RUN DESTROY_ALL

    export ANSIBLE_INVENTORY
    export VENOM_ROOT_DIR
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

    if ((  $AVAILABLE_SPACE > $MANDATORY_SPACE )); then
        echo "Enough space on system to run tests."
    else
        die "There is not enough space on system to run tests. Skipping tests."
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

run() {
    check_free_space
    log_section "Tests"
    start_and_provision_pf_vm ${PF_VM_NAMES}
    if [ -n "${INT_TEST_VM_NAMES}" ]; then
        start_and_provision_other_vm ${INT_TEST_VM_NAMES}
    else
        log_subsection "No additional VM to start and provision"
    fi
    run_tests
}

# The Linode box bucket is private, so Vagrant can't fetch our boxes from box_url
# directly (403). Pre-fetch them with authenticated rclone, driven by the VM's
# box_url in the inventory (single source of truth). Public boxes (generic/rhel8,
# debian/*) have no bucket URL and are fetched by Vagrant directly.
prefetch_private_box() {
    local vm=$1

    local box_url
    box_url=$(python3 - "${ANSIBLE_INVENTORY}/hosts" "${vm}" <<'PY' 2>/dev/null || true
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
PY
)
    # Public boxes (debian/*, generic/rhel8) have no bucket URL: Vagrant fetches them.
    case "${box_url}" in
        *packetfence-vagrant-box*) ;;
        *) return 0 ;;
    esac

    # Private box: creds are mandatory; fail clearly instead of a later vagrant 403.
    [ -n "${RCLONE_ACCESS_KEY_ID:-}" ] || \
        die "VM '${vm}' needs private box '${box_url}' but RCLONE_ACCESS_KEY_ID is unset (set RCLONE_ACCESS_KEY_ID/RCLONE_SECRET_ACCESS_KEY/RCLONE_LINODE_URL)."

    local setup_script="${VAGRANT_LIB_DIR:-${VENOM_ROOT_DIR}/../../ci/lib/vagrant}/setup-vagrant-box.sh"
    local box_name                                    # .../<box_name>/metadata.json
    box_name=$(basename "$(dirname "${box_url}")")
    echo "===> Pre-fetching private box '${box_name}' for VM '${vm}'"
    BOX_NAME="${box_name}" "${setup_script}" || die "failed to fetch box ${box_name} for ${vm}"
}

# Start with or without VM
start_vm() {
    local vm=$1
    local dotfile_path=$2
    declare -p dotfile_path
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
        ( cd ${VAGRANT_DIR}; \
          run_ansible_galaxy ${VAGRANT_DIR}/requirements.yml force ; \
          ansible-playbook site.yml -l $vm )
    else
        echo "Machine $vm doesn't exist, start and provision with Vagrant"
        prefetch_private_box ${vm}
        ( cd ${VAGRANT_DIR} ; \
          run_ansible_galaxy ${VAGRANT_DIR}/requirements.yml force ; \
          VAGRANT_DOTFILE_PATH=${dotfile_path} \
                  vagrant up \
                  ${vm} \
                  ${VAGRANT_UP_OPTS} 2>&1 | filter_vagrant_progress )
    fi
}

start_and_provision_pf_vm() {
    local vm_names=${@:-vmname}
    log_subsection "Start and provision PacketFence $vm_names"
    for vm in ${vm_names}; do
        start_vm ${vm} ${VAGRANT_PF_DOTFILE_PATH}
    done
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
    run_ansible_galaxy ${VENOM_ROOT_DIR}/requirements.yml force

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

destroy() {
    log_section "Destroy virtual machines"
    resume_paused_vms
    destroy_pf_vm
    destroy_other_vm
    delete_dir_if_exists ${VAGRANT_PF_DOTFILE_PATH}
    delete_dir_if_exists ${VAGRANT_COMMON_DOTFILE_PATH}
    destroy_paused_vms
}

# try to restart paused vms
resume_paused_vms() {
    log_subsection "Resuming paused VMs"
    for vm in $(virsh list --name --state-paused); do
        echo "Resuming VM: $vm"
        virsh resume "$vm" || true
    done
}

# using "|| true" as a workaround to unusual behavior
# see https://github.com/hashicorp/vagrant/issues/10024#issuecomment-404965057
destroy_pf_vm() {
    log_subsection "Vagrant Destroy PF"
    ( cd $VAGRANT_DIR ; \
      VAGRANT_DOTFILE_PATH=${VAGRANT_PF_DOTFILE_PATH} vagrant destroy -f || true )
}

# using "|| true" as a workaround to unusual behavior
# see https://github.com/hashicorp/vagrant/issues/10024#issuecomment-404965057
destroy_other_vm() {
    log_subsection "Vagrant Destroy other VMs"
    ( cd $VAGRANT_DIR ; \
      VAGRANT_DOTFILE_PATH=${VAGRANT_COMMON_DOTFILE_PATH} vagrant destroy -f || true )
}

destroy_paused_vms() {
    log_subsection "Virsh Destroy Paused VMs on the runner"
    for vm in $(virsh list --name --state-paused); do
        echo "Destroying and undefining VM: $vm"
        virsh destroy "$vm" && virsh undefine "$vm" --remove-all-storage || true
    done
}

destroy_all_vms() {
    log_subsection "Visrh Destroy ALL VMs on the runner"
    for vm in $(virsh list --name); do
        echo "Destroying and undefining VM: $vm"
        virsh destroy "$vm" && virsh undefine "$vm" --remove-all-storage || true
    done
}

configure_and_check

case $1 in
    run) run ;;
    run_tests) run_tests ;;
    destroy) destroy ;;
    teardown) teardown ;;
    *) die "Wrong argument"
esac
