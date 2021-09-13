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
    CI_COMMIT_TAG=${CI_COMMIT_TAG:-}
    CI_PIPELINE_ID=${CI_PIPELINE_ID:-}
    PF_MINOR_RELEASE=${PF_MINOR_RELEASE:-}
    PF_VM_NAME=${PF_VM_NAME:-}
    INT_TEST_VM_NAMES=${INT_TEST_VM_NAMES:-}
    DESTROY_VMS=${DESTROY_VMS:-}

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
}

start_and_provision() {
    local vm_names=${@:-vmname}
    log_subsection "Start and provision $vm_names"

    ( cd ${VAGRANT_DIR} ; \
      # always use latest boxes version
      vagrant box update ${vm_names} ; \
      vagrant up ${vm_names} ${VAGRANT_UP_OPTS} )
}

teardown() {
    log_section "Teardown"
    delete_ansible_files
    destroy ${PF_VM_NAME} ${INT_TEST_VM_NAMES}
}

delete_ansible_files() {
    log_subsection "Remove Ansible files"
    delete_dir_if_exists ${VAGRANT_DIR}/roles
    delete_dir_if_exists ${VAGRANT_DIR}/ansible_collections
}

halt_and_teardown() {
    local pf_vm_name=$1
    local vm_names=${@:-}
    unregister_rhel $pf_vm_name
    log_subsection "Halt virtual machine(s)"

    # using "|| true" as a workaround to unusual behavior
    # see https://github.com/hashicorp/vagrant/issues/10024#issuecomment-404965057
    if [ -z "${vm_names}" ]; then
        echo "Shutdown all VM"
        ( cd $VAGRANT_DIR ; \
          vagrant halt -f )
    else
        ( cd $VAGRANT_DIR ; \
          vagrant halt -f ${vm_names} )
    fi

    if [ "$TEARDOWN" = "yes" ]; then
        teardown
    else
        echo "Teardown disabled, VMs will be kept until an identical job is launched"
    fi
}

unregister_rhel() {
    log_subsection "Unregister RHEL subscription"
    ( cd $VAGRANT_DIR ; \
      ansible-playbook playbooks/unregister_rhel_subscription.yml -l $pf_vm_name )
}

destroy() {
    log_subsection "Destroy virtual machine(s)"
    local vm_names=${@:-}

    # using "|| true" as a workaround to unusual behavior
    # see https://github.com/hashicorp/vagrant/issues/10024#issuecomment-404965057
    if [ -z "${vm_names}" ]; then
        echo "Destroy all VM"
        ( cd $VAGRANT_DIR ; \
          vagrant destroy -f || true )
        delete_dir_if_exists ${VAGRANT_PF_DOTFILE_PATH}
        delete_dir_if_exists ${VAGRANT_COMMON_DOTFILE_PATH}
    else
        ( cd $VAGRANT_DIR ; \
          vagrant destroy -f ${vm_names} || true )
        for vm in ${vm_names}; do
            delete_dir_if_exists ${VAGRANT_PF_DOTFILE_PATH}/machines/${vm}
            delete_dir_if_exists ${VAGRANT_COMMON_DOTFILE_PATH}/machines/${vm}
        done
    fi
}

run() {
    log_section "Tests"
    declare -p RUN_TESTS
    declare -p PERL_UNIT_TESTS GOLANG_UNIT_TESTS
    declare -p INTEGRATION_TESTS    
    if [ "$RUN_TESTS" = "yes" ]; then
        start_and_provision ${PF_VM_NAME}
        if [ "$PERL_UNIT_TESTS" = "yes" ] || [ "$GOLANG_UNIT_TESTS" = "yes" ]; then
            run_shell_provisioner ${PF_VM_NAME} run-unit-tests
        fi
        if [ "$INTEGRATION_TESTS" = "yes" ]; then
           start_and_provision ${INT_TEST_VM_NAMES}
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
      vagrant provision $vm_name --provision-with="${provisioner_name}" )
}

configure_and_check

case $1 in
    run) run ;;
    halt_and_teardown) halt_and_teardown ${PF_VM_NAME} ${INT_TEST_VM_NAMES} ;;
    delete) delete_ansible_files ;;
    teardown) teardown ;;
    *)   die "Wrong argument"
esac
