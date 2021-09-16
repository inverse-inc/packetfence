#!/bin/bash
set -o nounset -o pipefail -o errexit

# Script to run 'test' stage of pipeline

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
    ANSIBLE_STDOUT_CALLBACK=${ANSIBLE_STDOUT_CALLBACK:-yaml}
    VAGRANT_FORCE_COLOR=${VAGRANT_FORCE_COLOR:-true}
    VAGRANT_ANSIBLE_VERBOSE=${VAGRANT_ANSIBLE_VERBOSE:-false}
    VAGRANT_DIR=${VAGRANT_DIR:-'../../../addons/vagrant'}
    VAGRANT_PF_DOTFILE_PATH="${VAGRANT_PF_DOTFILE_PATH:-${VAGRANT_DIR}/.vagrant}"
    VAGRANT_COMMON_DOTFILE_PATH="${VAGRANT_COMMON_DOTFILE_PATH:-${VAGRANT_DIR}/.vagrant}"
    VAGRANT_UP_OPTS=${VAGRANT_UP_OPTS:-'--no-destroy-on-error --no-parallel'}
    # only provision with a provisionner called site_ansible in Vagrantfile
    VAGRANT_PROVISION_ANSIBLE_OPTS=${VAGRANT_PROVISION_ANSIBLE_OPTS:-'--provision-with=site_ansible'}
    CI_COMMIT_TAG=${CI_COMMIT_TAG:-}
    CI_PIPELINE_ID=${CI_PIPELINE_ID:-}
    PF_MINOR_RELEASE=${PF_MINOR_RELEASE:-}
    PF_VM_NAME=${PF_VM_NAME:-}
    INT_TEST_VM_NAMES=${INT_TEST_VM_NAMES:-}
    DESTROY_ALL=${DESTROY_ALL:-no}


    # Tests
    PERL_UNIT_TESTS=${PERL_UNIT_TESTS:-}
    GOLANG_UNIT_TESTS=${GOLANG_UNIT_TESTS:-}
    INTEGRATION_TESTS=${INTEGRATION_TESTS:-}
    RUN_TESTS=${RUN_TESTS:-no}
    if [ "$PERL_UNIT_TESTS" = "yes" ]; then
        RUN_TESTS=${PERL_UNIT_TESTS}
    fi
    if [ "$GOLANG_UNIT_TESTS" = "yes" ]; then
        RUN_TESTS=${GOLANG_UNIT_TESTS}
    fi
    if [ "$INTEGRATION_TESTS" = "yes" ]; then
        RUN_TESTS=${INTEGRATION_TESTS}
    fi
    
    declare -p VAGRANT_DIR VAGRANT_ANSIBLE_VERBOSE VAGRANT_PF_DOTFILE_PATH VAGRANT_COMMON_DOTFILE_PATH
    declare -p CI_COMMIT_TAG CI_PIPELINE_ID PF_MINOR_RELEASE
    declare -p PF_VM_NAME INT_TEST_VM_NAMES
    declare -p DESTROY_ALL
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
            echo "Starting $vm using libvirt, provisioning through Vagrant"
            virsh -c qemu:///system start --domain $machine_uuid
            ( cd ${VAGRANT_DIR} ; \
              VAGRANT_DOTFILE_PATH=${VAGRANT_COMMON_DOTFILE_PATH} \
                                  vagrant provision \
                                  ${vm} \
                                  ${VAGRANT_PROVISION_ANSIBLE_OPTS} )
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

destroy() {
    log_subsection "Destroy virtual machine(s)"

    # using "|| true" as a workaround to unusual behavior
    # see https://github.com/hashicorp/vagrant/issues/10024#issuecomment-404965057
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

destroy_pf_vm() {
    ( cd $VAGRANT_DIR ; \
      VAGRANT_DOTFILE_PATH=${VAGRANT_PF_DOTFILE_PATH} vagrant destroy -f || true )
}

destroy_other_vm() {
    ( cd $VAGRANT_DIR ; \
      VAGRANT_DOTFILE_PATH=${VAGRANT_COMMON_DOTFILE_PATH} vagrant destroy -f || true )
}

run() {
    log_section "Tests"
    declare -p RUN_TESTS
    declare -p PERL_UNIT_TESTS GOLANG_UNIT_TESTS
    declare -p INTEGRATION_TESTS    
    if [ "$RUN_TESTS" = "yes" ]; then
        start_and_provision_pf_vm ${PF_VM_NAME}
        if [ "$PERL_UNIT_TESTS" = "yes" ] || [ "$GOLANG_UNIT_TESTS" = "yes" ]; then
            run_shell_provisioner ${PF_VM_NAME} run-unit-tests
        fi
        if [ "$INTEGRATION_TESTS" = "yes" ]; then
           start_and_provision_other_vm ${INT_TEST_VM_NAMES}
           run_shell_provisioner ${PF_VM_NAME} run-integration-tests
        fi
    else
        echo "No tests to run"
    fi
}

run_shell_provisioner() {
    local vm_name=${1:-vmname}
    local provisioner_name=${2:-fooprov}
    log_subsection "Run shell provisionner ${provisioner_name}"
    ( cd $VAGRANT_DIR ; \
      VAGRANT_DOTFILE_PATH=${VAGRANT_PF_DOTFILE_PATH} vagrant provision \
                          $vm_name \
                          --provision-with="${provisioner_name}" )
}

configure_and_check

case $1 in
    run) run ;;
    halt) halt ;;
    delete) delete_ansible_files ;;
    teardown) teardown ;;
    *)   die "Wrong argument"
esac
