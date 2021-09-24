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
    # Tests
    VENOM_ROOT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))
    SCENARIOS_BASE_DIR=${VENOM_ROOT_DIR}/scenarios
    SCENARIOS_TO_RUN=${SCENARIOS_TO_RUN:-foo bar}
    PF_VM_NAME=${PF_VM_NAME:-}
    INT_TEST_VM_NAMES=${INT_TEST_VM_NAMES:-}
    DESTROY_ALL=${DESTROY_ALL:-no}

    if [ -n "${INT_TEST_VM_NAMES}" ]; then
        VM_LIST="${PF_VM_NAME} ${INT_TEST_VM_NAMES}"
    else
        VM_LIST=${PF_VM_NAME}
    fi
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
    declare -p ANSIBLE_INVENTORY
    declare -p CI_COMMIT_TAG CI_PIPELINE_ID PF_MINOR_RELEASE
    declare -p VM_LIST
    declare -p SCENARIOS_TO_RUN DESTROY_ALL

    export ANSIBLE_INVENTORY
}

run() {
    log_section "Tests"
    start_and_provision_pf_vm ${PF_VM_NAME}
    if [ -n "${INT_TEST_VM_NAMES}" ]; then
        start_and_provision_other_vm ${INT_TEST_VM_NAMES}
    else
        echo "No additional VM to start and provision"
    fi
    run_tests
}

start_and_provision_pf_vm() {
    local vm_names=${@:-vmname}
    log_subsection "Start and provision $vm_names"

    ( cd ${VAGRANT_DIR} ; \
      VAGRANT_DOTFILE_PATH=${VAGRANT_PF_DOTFILE_PATH} \
                          vagrant up \
                          ${vm_names} \
                          ${VAGRANT_UP_OPTS} )
}

start_and_provision_other_vm() {
    local vm_names=${@:-vmname}
    log_subsection "Start and provision $vm_names"

    for vm in ${vm_names}; do
        if [ -e "${VAGRANT_COMMON_DOTFILE_PATH}/machines/${vm}/libvirt/id" ]; then
            echo "Machine $vm already exists"
            machine_uuid=$(cat ${VAGRANT_COMMON_DOTFILE_PATH}/machines/${vm}/libvirt/id)
            # hack to overcome the fact that node01 doesn't have IP address after first provisioning
            # vagrant up will fail
            echo "Starting $vm using libvirt, provisioning using Ansible (without Vagrant)"
            virsh -c qemu:///system start --domain $machine_uuid
            # let time for the VM to boot before using ansible
            sleep 60
            ( cd ${VAGRANT_DIR}; \
              ansible-playbook site.yml -l $vm )
        else
            echo "Machine $vm doesn't exist, start and provision with Vagrant"
            ( cd ${VAGRANT_DIR} ; \
              VAGRANT_DOTFILE_PATH=${VAGRANT_COMMON_DOTFILE_PATH} \
                          vagrant up \
                          ${vm} \
                          ${VAGRANT_UP_OPTS} )
       fi
    done
}

run_tests() {
    log_subsection "Configure VM for tests and run tests"
    # install roles and collections in VENOM_ROOT_DIR
    ansible-galaxy install -r ${VENOM_ROOT_DIR}/requirements.yml    
    for scenario_name in ${SCENARIOS_TO_RUN}; do
        scenario_path="${SCENARIOS_BASE_DIR}/${scenario_name}"
        if [ -e "${scenario_path}/ansible_inventory.yml" ]; then
            echo "Additional Ansible inventory detected, will use it"
            # will find roles and collections in VENOM_ROOT_DIR
            ansible-playbook ${scenario_path}/site.yml -l $VM_LIST -e "@${scenario_path}/ansible_inventory.yml"
        else
            ansible-playbook ${scenario_path}/site.yml -l $VM_LIST
        fi
    done
}

halt() {
    unregister_rhel
    log_subsection "Halt virtual machine(s)"

    ( cd $VAGRANT_DIR ; \
      VAGRANT_DOTFILE_PATH=${VAGRANT_PF_DOTFILE_PATH} vagrant halt -f ${PF_VM_NAME} )

    ( cd $VAGRANT_DIR ; \
      VAGRANT_DOTFILE_PATH=${VAGRANT_COMMON_DOTFILE_PATH} vagrant halt -f ${INT_TEST_VM_NAMES} )
}

unregister_rhel() {
    log_subsection "Unregister RHEL subscription"
    ( cd $VAGRANT_DIR ; \
      ansible-playbook playbooks/unregister_rhel_subscription.yml -l $PF_VM_NAME )
}

teardown() {
    log_section "Teardown"
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
