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

run() {
    log_section "Tests"
    start_and_provision_pf_vm ${PF_VM_NAMES}
    if [ -n "${INT_TEST_VM_NAMES}" ]; then
        start_and_provision_other_vm ${INT_TEST_VM_NAMES}
    else
        log_subsection "No additional VM to start and provision"
    fi
    run_tests
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
          ansible-playbook site.yml -l $vm )
    else
        echo "Machine $vm doesn't exist, start and provision with Vagrant"
        ( cd ${VAGRANT_DIR} ; \
          VAGRANT_DOTFILE_PATH=${dotfile_path} \
                  vagrant up \
                  ${vm} \
                  ${VAGRANT_UP_OPTS} )
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
    ansible-galaxy install --force -r ${VENOM_ROOT_DIR}/requirements.yml
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

unconfigure() {
    log_subsection "Unconfigure virtual machines"
    # when we call "make halt" without options (localdev)
    # no VM are provided
    if [ -n "${ANSIBLE_VM_LIST}" ]; then
        ( cd $VAGRANT_DIR ; \
          ansible-playbook teardown.yml -l $ANSIBLE_VM_LIST )
    else
        echo "No VM detected, nothing to unconfigure"
    fi
}

halt() {
    # work as try/catch to continue even if an error has been detected
    # We always want VM to be halted even if Ansible failed
    if unconfigure; then
        echo "Ansible teardown succeed"
    else
        echo "Ansible teardown failed"
    fi
    log_subsection "Halt virtual machine(s)"

    ( cd $VAGRANT_DIR ; \
      VAGRANT_DOTFILE_PATH=${VAGRANT_PF_DOTFILE_PATH} vagrant halt -f )

    ( cd $VAGRANT_DIR ; \
      VAGRANT_DOTFILE_PATH=${VAGRANT_COMMON_DOTFILE_PATH} vagrant halt -f )
}

teardown() {
    log_section "Teardown"
    halt
    delete_ansible_files
    destroy
}

delete_ansible_files() {
    log_subsection "Remove Ansible files"
    delete_dir_if_exists ${VAGRANT_DIR}/roles
    delete_dir_if_exists ${VAGRANT_DIR}/ansible_collections
}

destroy() {
    log_subsection "Destroy virtual machine(s)"

    if [ "$DESTROY_ALL" = "yes" ]; then
        echo "Destroy all VM"
        destroy_pf_vm
        destroy_other_vm
        delete_dir_if_exists ${VAGRANT_PF_DOTFILE_PATH}
        delete_dir_if_exists ${VAGRANT_COMMON_DOTFILE_PATH}
    else
        destroy_pf_vm
        delete_dir_if_exists ${VAGRANT_PF_DOTFILE_PATH}
    fi
}

# using "|| true" as a workaround to unusual behavior
# see https://github.com/hashicorp/vagrant/issues/10024#issuecomment-404965057
destroy_pf_vm() {
    ( cd $VAGRANT_DIR ; \
      VAGRANT_DOTFILE_PATH=${VAGRANT_PF_DOTFILE_PATH} vagrant destroy -f || true )
}

# using "|| true" as a workaround to unusual behavior
# see https://github.com/hashicorp/vagrant/issues/10024#issuecomment-404965057
destroy_other_vm() {
    ( cd $VAGRANT_DIR ; \
      VAGRANT_DOTFILE_PATH=${VAGRANT_COMMON_DOTFILE_PATH} vagrant destroy -f || true )
}


configure_and_check

case $1 in
    run) run ;;
    run_tests) run_tests ;;
    halt) halt ;;
    delete) delete_ansible_files ;;
    teardown) teardown ;;
    *) die "Wrong argument"
                                              
esac
