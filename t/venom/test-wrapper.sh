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

delete_dir_if_exists() {
    local dir=${1}
    if [ -d "${dir}" ]; then
        rm -r ${dir}
        echo "Directory ${dir} removed"
    else
        echo "No ${dir} directory to remove"
    fi
}

# Collapse vagrant Progress: N% redraws to only the latest frame per burst.
filter_vagrant_progress() {
    local esc=$'\033'
    awk -v esc="$esc" '
      function flush_pending() {
          if (pending != "") { print pending; pending = ""; fflush() }
      }
      {
          n = split($0, frames, "\r")
          line = frames[n]
          clean = line
          gsub(esc "\\[[0-9;]*[A-Za-z]", "", clean)
          if (clean ~ /^[ \t]*$/) next
          if (clean ~ /^[ \t]*([A-Za-z0-9._-]+: )?Progress: [0-9]+%([ \t]*\(.*\))?[ \t]*$/) {
              pending = line
              next
          }
          flush_pending()
          print line; fflush()
      }
      END { flush_pending() }
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

    # Golden box (set by test jobs that consume a pre-baked golden image).
    # When USE_GOLDEN_BOX=yes, PF VMs (pfel8dev/pfdeb12dev) boot from the
    # per-pipeline pre-baked .box at ${GOLDEN_BOX_DIR}/pf<arch>golden.box,
    # skipping site.yml and the configurator wizard. Defaults preserve the
    # original behavior.
    USE_GOLDEN_BOX=${USE_GOLDEN_BOX:-no}
    GOLDEN_BOX_VERSION=${GOLDEN_BOX_VERSION:-}
    GOLDEN_BOX_DIR=${GOLDEN_BOX_DIR:-}
    SKIP_CONFIGURATOR_BAKED=${SKIP_CONFIGURATOR_BAKED:-no}
    FALLBACK_TO_FULL_PROVISION=${FALLBACK_TO_FULL_PROVISION:-no}

    declare -p VAGRANT_DIR VAGRANT_ANSIBLE_VERBOSE VAGRANT_PF_DOTFILE_PATH VAGRANT_COMMON_DOTFILE_PATH
    declare -p ANSIBLE_INVENTORY RESULT_DIR VENOM_ROOT_DIR
    declare -p CI_COMMIT_TAG CI_PIPELINE_ID PF_MINOR_RELEASE
    declare -p PF_VM_NAMES CLUSTER_NAME INT_TEST_VM_NAMES ALL_VM_NAMES ANSIBLE_VM_LIST
    declare -p SCENARIOS_TO_RUN DESTROY_ALL
    declare -p USE_GOLDEN_BOX GOLDEN_BOX_VERSION GOLDEN_BOX_DIR
    declare -p SKIP_CONFIGURATOR_BAKED FALLBACK_TO_FULL_PROVISION

    export ANSIBLE_INVENTORY
    export VENOM_ROOT_DIR
    export USE_GOLDEN_BOX GOLDEN_BOX_VERSION GOLDEN_BOX_DIR
    export SKIP_CONFIGURATOR_BAKED
}

# Maps a PF VM name to its golden box arch ("" if the VM is not a golden
# bake target). Kept in sync with golden_arch_map in pfservers/Vagrantfile.
golden_arch_for_pf_vm() {
    case "$1" in
        pfel8dev)   echo el8 ;;
        pfdeb12dev) echo deb12 ;;
        *)          echo "" ;;
    esac
}

maybe_fallback_to_full_provision() {
    local reason=$1
    if [ "${FALLBACK_TO_FULL_PROVISION}" = "yes" ]; then
        echo "FALLBACK_TO_FULL_PROVISION=yes — falling back to full site.yml provisioning (reason: ${reason})"
        USE_GOLDEN_BOX=no
        export USE_GOLDEN_BOX
        return 0
    fi
    die "Cannot use golden box: ${reason}. Set FALLBACK_TO_FULL_PROVISION=yes to fall back to site.yml."
}

# Register the per-pipeline .box with the local Vagrant box store so
# `vagrant up` pulls from it instead of Vagrant Cloud.
register_golden_box_or_fallback() {
    local vm=$1
    local arch
    arch=$(golden_arch_for_pf_vm "${vm}")
    [ -n "${arch}" ] || return 0

    if [ -z "${GOLDEN_BOX_VERSION}" ] || [ -z "${GOLDEN_BOX_DIR}" ]; then
        maybe_fallback_to_full_provision "GOLDEN_BOX_VERSION or GOLDEN_BOX_DIR is empty"
        return $?
    fi

    local box_name="inverse-inc/pf${arch}golden"
    local box_file="${GOLDEN_BOX_DIR}/pf${arch}golden.box"

    if [ ! -f "${box_file}" ]; then
        maybe_fallback_to_full_provision "missing golden box file ${box_file}"
        return $?
    fi

    log_subsection "Register golden box ${box_name} v${GOLDEN_BOX_VERSION} from ${box_file}"
    if ! vagrant box add --force --name "${box_name}" --box-version "${GOLDEN_BOX_VERSION}" "${box_file}"; then
        maybe_fallback_to_full_provision "vagrant box add ${box_name} failed"
        return $?
    fi
}

# After a golden-box `vagrant up`, libvirt assigns fresh MACs so the PF
# interface->IP bindings baked at configurator time may need re-applying.
refresh_network_post_golden() {
    local vm=$1
    log_subsection "Refresh network on ${vm} (post-golden boot)"
    ( cd "${VAGRANT_DIR}" ; \
      ansible-playbook playbooks/refresh_network_post_golden.yml -l "${vm}" )
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

# The box bucket is private (Vagrant box_url fetch 403s), so pre-fetch our boxes
# via rclone keyed on the VM's inventory box_url. Public boxes have none -> skip.
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
    case "${box_url}" in
        *packetfence-vagrant-box*) ;;
        *) return 0 ;;   # public box: let Vagrant fetch it
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
    run_ansible_galaxy_once ${VAGRANT_DIR}/requirements.yml

    # arch is non-empty only for golden-eligible PF VMs in golden mode
    local arch=""
    if [ "${USE_GOLDEN_BOX}" = "yes" ]; then
        arch=$(golden_arch_for_pf_vm "${vm}")
    fi

    if [ -e "${dotfile_path}/machines/${vm}/libvirt/id" ]; then
        echo "Machine $vm already exists"
        start_existing_vm ${vm} ${dotfile_path}
        wait_for_ssh ${vm}
        if [ -n "${arch}" ]; then
            # Golden mode: PF VM is already fully provisioned + configured.
            # Re-running site.yml would undo the bake, so only refresh network.
            refresh_network_post_golden "${vm}"
        else
            ( cd ${VAGRANT_DIR}; \
              ansible-playbook site.yml -l $vm )
        fi
    else
        echo "Machine $vm doesn't exist, start and provision with Vagrant"
        if [ -n "${arch}" ]; then
            register_golden_box_or_fallback "${vm}"
            # register_golden_box_or_fallback may have flipped USE_GOLDEN_BOX
            # to "no" via the fallback path; recompute arch to honor it.
            arch=""
            [ "${USE_GOLDEN_BOX}" = "yes" ] && arch=$(golden_arch_for_pf_vm "${vm}")
        fi
        if [ -n "${arch}" ]; then
            ( cd "${VAGRANT_DIR}" ; \
              SKIP_SITE_PROVISION=yes \
              VAGRANT_DOTFILE_PATH=${dotfile_path} \
                      vagrant up \
                      ${vm} \
                      ${VAGRANT_UP_OPTS} 2>&1 | filter_vagrant_progress )
            refresh_network_post_golden "${vm}"
        else
            prefetch_private_box "${vm}"
            ( cd "${VAGRANT_DIR}" ; \
              VAGRANT_DOTFILE_PATH=${dotfile_path} \
                      vagrant up \
                      ${vm} \
                      ${VAGRANT_UP_OPTS} 2>&1 | filter_vagrant_progress )
        fi
    fi
}

start_and_provision_pf_vm() {
    local vm_names=${@:-vmname}
    log_subsection "Start and provision PacketFence $vm_names"
    run_ansible_galaxy_once ${VAGRANT_DIR}/requirements.yml
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

    mkdir -p "${RESULT_DIR}"
    local ansible_log="${RESULT_DIR}/ansible-run_tests.log"
    for scenario_name in ${SCENARIOS_TO_RUN}; do
        scenario_path="${SCENARIOS_BASE_DIR}/${scenario_name}"
        if [ -e "${scenario_path}/ansible_inventory.yml" ]; then
            echo "Additional Ansible inventory detected, will use it"
            # will find roles and collections in VENOM_ROOT_DIR
            ansible-playbook ${scenario_path}/site.yml -l $ANSIBLE_VM_LIST -e "@${scenario_path}/ansible_inventory.yml" 2>&1 | tee -a "${ansible_log}"
        else
            ansible-playbook ${scenario_path}/site.yml -l $ANSIBLE_VM_LIST 2>&1 | tee -a "${ansible_log}"
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
    delete_dir_if_exists "${VAGRANT_PF_DOTFILE_PATH}"
    delete_dir_if_exists "${VAGRANT_COMMON_DOTFILE_PATH}"
    delete_ansible_files
}

configure_and_check

case $1 in
    run) run ;;
    run_tests) time_phase "Run scenarios: ${SCENARIOS_TO_RUN}" run_tests ;;
    destroy) destroy ;;
    teardown) teardown ;;
    *) die "Wrong argument"
esac
