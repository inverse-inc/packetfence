#!/bin/bash
set -o nounset -o pipefail

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
    SCENARIO_TO_RUN=${SCENARIOS_BASE_DIR}/${SCENARIO_TO_RUN:-foo}
    INT_TEST_VM_NAMES=${INT_TEST_VM_NAMES:-}

    # Vagrant
    VAGRANT_FORCE_COLOR=${VAGRANT_FORCE_COLOR:-true}
    VAGRANT_ANSIBLE_VERBOSE=${VAGRANT_ANSIBLE_VERBOSE:-false}
    VAGRANT_UP_OPTS=${VAGRANT_UP_OPTS:-'--no-destroy-on-error --no-parallel'}
    VAGRANT_DIR=$(readlink -e ../../addons/vagrant)
    VAGRANT_DOTFILE_PATH="${VAGRANT_DOTFILE_PATH:-${VAGRANT_DIR}/.vagrant}"

    # Ansible configs
    ANSIBLE_INVENTORY="${VAGRANT_DIR}/inventory"

    CI_COMMIT_TAG=${CI_COMMIT_TAG:-}
    CI_PIPELINE_ID=${CI_PIPELINE_ID:-}
    PF_MINOR_RELEASE=${PF_MINOR_RELEASE:-}


    declare -p VAGRANT_DIR VAGRANT_ANSIBLE_VERBOSE VAGRANT_DOTFILE_PATH
    declare -p ANSIBLE_INVENTORY
    declare -p CI_COMMIT_TAG CI_PIPELINE_ID PF_MINOR_RELEASE
    declare -p INT_TEST_VM_NAMES
    declare -p SCENARIO_TO_RUN

    export ANSIBLE_INVENTORY
}

run() {
    log_section "Tests"
    start_and_provision ${INT_TEST_VM_NAMES}
    run_tests
}

start_and_provision() {
    local vm_names=${@:-vmname}
    log_subsection "Start and provision $vm_names"

    ( cd ${VAGRANT_DIR} ; \
      vagrant up ${vm_names} ${VAGRANT_UP_OPTS} )
}

run_tests() {
    log_subsection "Configure VM for tests and run integration tests"
    # install roles and collections in VENOM_ROOT_DIR
    # TODO: test if file exist
    ansible-galaxy install -r ${SCENARIO_TO_RUN}/requirements.yml
    # will find roles and collections in VENOM_ROOT_DIR
    ansible-playbook ${SCENARIO_TO_RUN}/site.yml -e "@${SCENARIO_TO_RUN}/ansible_inventory.yml"
}

halt() {
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
}

teardown() {
    log_section "Teardown"
    destroy ${INT_TEST_VM_NAMES}
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
        delete_dir_if_exists ${VAGRANT_DOTFILE_PATH}
    else
        ( cd $VAGRANT_DIR ; \
          vagrant destroy -f ${vm_names} || true )
        for vm in ${vm_names}; do
            delete_dir_if_exists ${VAGRANT_DOTFILE_PATH}/machines/${vm}
        done
    fi
}

configure_and_check

case $1 in
    run) run ;;
    run_tests) run_tests ;;
    halt) halt ${INT_TEST_VM_NAMES} ;;
    delete) delete_ansible_files ;;
    teardown) teardown ;;
    *) die "Wrong argument"
                                              
esac
