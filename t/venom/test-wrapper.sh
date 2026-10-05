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
    LOCAL_BAKED_BOX=${LOCAL_BAKED_BOX:-no}
    export USE_VAGRANT_BOX VAGRANT_BOX_VERSION
    export SKIP_CONFIGURATOR_BAKED LOCAL_BAKED_BOX
}

# Map eligible PF VMs to their per-pipeline base box (empty if ineligible).
# Kept in sync with baked_base_box in pfservers/Vagrantfile.
# LOCAL_BAKED_BOX=yes maps localdev VMs to a `bake-vagrant-img.sh local` box.
baked_box_for_pf_vm() {
    case "$1" in
        pfel8dev|pf[123]el8dev) echo pfel8dev ;;
        pfdeb12dev|pf[123]deb12dev) echo pfdeb12dev ;;
        pfel8localdev|pf[123]el8localdev|pfdeb12localdev|pf[123]deb12localdev)
            if [ "${LOCAL_BAKED_BOX:-no}" = yes ]; then
                echo "${1/#pf[123]/pf}"
            else
                echo ""
            fi ;;
        *)                   echo "" ;;
    esac
}

maybe_fallback_to_full_provision() {
    local reason=$1
    if [ "${FALLBACK_TO_FULL_PROVISION}" = "yes" ]; then
        echo "FALLBACK_TO_FULL_PROVISION=yes — falling back to full site.yml provisioning (reason: ${reason})"
        USE_VAGRANT_BOX=no
        SKIP_CONFIGURATOR_BAKED=no
        export USE_VAGRANT_BOX SKIP_CONFIGURATOR_BAKED
        return 0
    fi
    die "Cannot use baked vagrant box: ${reason}. Set FALLBACK_TO_FULL_PROVISION=yes to fall back to site.yml."
}

# Register the baked box during VM startup, after run() has checked free
# space and reclaimed space if needed. The setup script skips downloading
# a box that is already registered for this pipeline.
register_vagrant_box_or_fallback() {
    local vm=$1
    local box=$(baked_box_for_pf_vm "${vm}")
    [ -n "${box}" ] || return 0

    if [ -z "${VAGRANT_BOX_VERSION}" ]; then
        maybe_fallback_to_full_provision "VAGRANT_BOX_VERSION is empty"
        return $?
    fi

    source "${VENOM_ROOT_DIR}/../../ci/lib/vagrant/box-category.sh"
    local box_name="inverse-inc/${box}-$(vagrant_box_category)"

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

# Skip ansible-galaxy (minutes per install) when the requirements are
# unchanged: checksum stamp in the install dir, then a runner-local cache.
# GALAXY_FORCE=yes reinstalls.
ANSIBLE_GALAXY_CACHE=${ANSIBLE_GALAXY_CACHE:-${HOME}/.cache/pf-ansible-galaxy}
ANSIBLE_GALAXY_CACHE_DAYS=${ANSIBLE_GALAXY_CACHE_DAYS:-14}
GALAXY_CONTENT_DIRS="roles ansible_collections"

run_ansible_galaxy_once() {
    local req_file=$1
    local req_dir=$(dirname ${req_file})
    local stamp=${req_dir}/ansible_collections/.requirements.sha256
    local req_sum=$( { cat ${req_file}; ansible-galaxy --version | head -1; } | sha256sum | cut -d ' ' -f 1)
    local entry=${ANSIBLE_GALAXY_CACHE}/${req_sum}
    local d

    if [ "${GALAXY_FORCE:-no}" != yes ]; then
        if [ -d ${req_dir}/roles ] && [ "$(cat ${stamp} 2>/dev/null)" = "${req_sum}" ]; then
            echo "Ansible requirements unchanged since last install, skipping: ${req_file}"
            return 0
        fi
        if [ -f ${entry}/.complete ]; then
            echo "Restoring Ansible requirements from runner cache ${entry}: ${req_file}"
            for d in ${GALAXY_CONTENT_DIRS}; do
                rm -rf ${req_dir}/${d}
                cp -a ${entry}/${d} ${req_dir}/${d}
            done
            touch ${entry} ${entry}/.complete
            echo "${req_sum}" > ${stamp}
            return 0
        fi
    fi

    # cd first: collections/roles paths in the local ansible.cfg are relative to CWD
    ( cd ${req_dir} && run_ansible_galaxy ${req_file} force ) || die "ansible-galaxy install failed: ${req_file}"
    mkdir -p $(dirname ${stamp})
    echo "${req_sum}" > ${stamp}
    save_ansible_galaxy_cache ${req_dir} ${entry} || echo "Could not save Ansible requirements to runner cache (non fatal)"
}

# Atomic save: first rename wins; failures are non fatal.
save_ansible_galaxy_cache() {
    local req_dir=$1 entry=$2 tmp d
    mkdir -p ${ANSIBLE_GALAXY_CACHE} || return 1
    find ${ANSIBLE_GALAXY_CACHE} -mindepth 1 -maxdepth 1 -type d \
         ! -newermt "-${ANSIBLE_GALAXY_CACHE_DAYS} days" -exec rm -rf {} + 2>/dev/null || true
    [ -f ${entry}/.complete ] && return 0
    tmp=$(mktemp -d -p ${ANSIBLE_GALAXY_CACHE} .tmp.XXXXXX) || return 1
    for d in ${GALAXY_CONTENT_DIRS}; do
        cp -a ${req_dir}/${d} ${tmp}/${d} || { rm -rf ${tmp}; return 1; }
    done
    touch ${tmp}/.complete
    mv -T ${tmp} ${entry} 2>/dev/null || rm -rf ${tmp}
}

run() {
    if [ "${SCENARIOS_TO_RUN}" = "cluster_configurator cluster_recovery" ]; then
        # Each phase gets its own clock. The CI job timeout must cover both
        # budgets plus teardown; setup can no longer consume recovery's time.
        time_phase "Cluster setup" timeout "${CLUSTER_SETUP_TIMEOUT:-120m}" "$0" prepare_cluster
        # C repeats the configurator's rolling reboot: skip it here
        SCENARIOS_TO_RUN=cluster_recovery RECOVERY_SCENARIOS="${RECOVERY_SCENARIOS:-A B D E F}" \
            time_phase "Cluster recovery" \
            timeout "${CLUSTER_RECOVERY_TIMEOUT:-150m}" "$0" run_tests
        return
    fi
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
prepare_cluster() {
    check_free_space
    time_phase "Import and prepare cluster nodes" start_and_provision_pf_vm ${PF_VM_NAMES}
    SCENARIOS_TO_RUN=cluster_configurator run_tests
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
# Prep/readdress playbooks for baked cluster clones (no-op for standalone VMs).
baked_cluster_playbook() {
    local playbook=$1 vm=$2
    [[ "${vm}" =~ ^pf[123](deb12|el8)(local)?dev$ ]] || return 0
    ( cd "${VAGRANT_DIR}"; ansible-playbook "playbooks/${playbook}" -l "${vm}" )
}

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
            baked_cluster_playbook cluster_prep_baked.yml "${vm}"
            refresh_network_post_import "${vm}"
            baked_cluster_playbook cluster_readdress_baked.yml "${vm}"
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
            baked_cluster_playbook cluster_prep_baked.yml "${vm}"
            refresh_network_post_import "${vm}"
            baked_cluster_playbook cluster_readdress_baked.yml "${vm}"
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

# Boot baked clones together and prepare them in one ansible run per playbook;
# the heavy PF starts in those playbooks are throttled to one node at a time.
start_baked_pf_vms() {
    local vm_names=$* vm cluster_vms=""
    local vm_list=${vm_names// /,}
    for vm in ${vm_names}; do
        [[ "${vm}" =~ ^pf[123](deb12|el8)(local)?dev$ ]] && cluster_vms="${cluster_vms},${vm}"
    done
    cluster_vms=${cluster_vms#,}
    ( cd "${VAGRANT_DIR}"
      SKIP_SITE_PROVISION=yes VAGRANT_DOTFILE_PATH="${VAGRANT_PF_DOTFILE_PATH}" \
          vagrant up ${vm_names} ${VAGRANT_UP_OPTS} 2>&1 | filter_vagrant_progress )
    if [ -n "${cluster_vms}" ]; then
        ( cd "${VAGRANT_DIR}"; ansible-playbook playbooks/cluster_prep_baked.yml -l "${cluster_vms}" )
    fi
    log_subsection "Refresh network on ${vm_list} (post-import boot)"
    ( cd "${VAGRANT_DIR}"; ansible-playbook playbooks/refresh_network_post_import.yml -l "${vm_list}" )
    if [ -n "${cluster_vms}" ]; then
        ( cd "${VAGRANT_DIR}"; ansible-playbook playbooks/cluster_readdress_baked.yml -l "${cluster_vms}" )
    fi
    log_subsection "Re-register RHEL subscription on ${vm_list} (post-import)"
    ( cd "${VAGRANT_DIR}"; ansible-playbook playbooks/register_rhel_subscription.yml -l "${vm_list}" )
}

start_and_provision_pf_vm() {
    local vm_names=${@:-vmname}
    log_subsection "Start and provision PacketFence $vm_names"
    run_ansible_galaxy_once ${VAGRANT_DIR}/requirements.yml
    if [ "${USE_VAGRANT_BOX}" = yes ]; then
        # The baked path is all-or-nothing: one unmapped node would otherwise be
        # fully provisioned while its peers boot from the baked box.
        local unmapped=""
        for vm in ${vm_names}; do
            [ -n "$(baked_box_for_pf_vm "${vm}")" ] || unmapped="${unmapped} ${vm}"
        done
        if [ -n "${unmapped}" ]; then
            maybe_fallback_to_full_provision "no baked box for:${unmapped}"
        fi
    fi
    if [ "${USE_VAGRANT_BOX}" = yes ]; then
        # Validate every node's box before creating any clones; fallback applies to all nodes.
        for vm in ${vm_names}; do
            register_vagrant_box_or_fallback "${vm}"
            [ "${USE_VAGRANT_BOX}" = yes ] || break
        done
        if [ "${USE_VAGRANT_BOX}" = yes ]; then
            start_baked_pf_vms ${vm_names}
            return
        fi
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
        if [ "${scenario_name}" = cluster_recovery ] && [ -n "${RESULT_DIR}" ]; then
            # Host output bypasses guest sanitization: the shared sampler only
            # emits allowlisted numeric kernel counters, never arbitrary text.
            python3 "${VAGRANT_DIR}/playbooks/files/sample-resource-usage.py" \
                "${RESULT_DIR}/runner/resource-usage.jsonl" >/dev/null 2>&1 &
            resource_sampler_pid=$!
            trap 'stop_resource_sampler' EXIT
            trap 'exit 143' TERM
            trap 'exit 130' INT
        fi
        scenario_path="${SCENARIOS_BASE_DIR}/${scenario_name}"
        # expose the vagrant dotfile path so scenarios that power-control VMs
        # (e.g. cluster_recovery) can resolve the libvirt domain UUID
        local dotfile_ev="vagrant_pf_dotfile_path=${VAGRANT_PF_DOTFILE_PATH}"
        # RECOVERY_SCENARIOS="A B D" limits cluster_recovery; unset runs all
        local scenarios_ev=()
        if [ "${scenario_name}" = cluster_recovery ] && [ -n "${RECOVERY_SCENARIOS:-}" ]; then
            [[ "${RECOVERY_SCENARIOS}" =~ ^[A-Z]( [A-Z])*$ ]] \
                || die "RECOVERY_SCENARIOS must be space-separated scenario IDs, got: ${RECOVERY_SCENARIOS}"
            scenarios_ev=(-e "{\"recovery_scenarios\": [$(printf '"%s",' ${RECOVERY_SCENARIOS} | sed 's/,$//')]}")
            echo "Recovery scenarios: ${RECOVERY_SCENARIOS}"
        fi
        if [ -e "${scenario_path}/ansible_inventory.yml" ]; then
            echo "Additional Ansible inventory detected, will use it"
            # will find roles and collections in VENOM_ROOT_DIR
            ansible-playbook ${scenario_path}/site.yml -l $ANSIBLE_VM_LIST -e "${dotfile_ev}" "${scenarios_ev[@]}" -e "@${scenario_path}/ansible_inventory.yml"
        else
            ansible-playbook ${scenario_path}/site.yml -l $ANSIBLE_VM_LIST -e "${dotfile_ev}" "${scenarios_ev[@]}"
        fi
        stop_resource_sampler
    done
}

stop_resource_sampler() {
    if [ -n "${resource_sampler_pid:-}" ]; then
        kill "${resource_sampler_pid}" 2>/dev/null || true
        wait "${resource_sampler_pid}" 2>/dev/null || true
        resource_sampler_pid=
    fi
}

teardown() {
    log_section "Teardown"
    # first: works even when every VM is unreachable, and guarantees RESULT_DIR
    # is non-empty so the job still uploads artifacts
    collect_runner_diagnostics
    ansible_teardown
    delete_ansible_files
}

ansible_teardown() {
    log_subsection "Ansible teardown (RHEL8 Unregister and Get Logs on all VM)"
    if [ -n "${ANSIBLE_VM_LIST}" ]; then
        ( cd $VAGRANT_DIR ; \
          ansible-playbook teardown.yml -l $ANSIBLE_VM_LIST ) \
            || echo "WARN: ansible teardown failed, keeping runner diagnostics"
    else
        echo "No VM detected, nothing to unconfigure"
    fi
}

# Runner-side view of the VMs. This is all we get about a VM that stopped
# answering SSH, since guest-side collection can't run on an unreachable host.
collect_runner_diagnostics() {
    log_subsection "Collect runner diagnostics"
    if [ -z "${RESULT_DIR}" ]; then
        echo "RESULT_DIR is unset, skipping runner diagnostics"
        return 0
    fi
    local out_dir="${RESULT_DIR}/runner"
    mkdir -p "${out_dir}"

    {
        echo "job:       ${CI_JOB_NAME:-localdev} ${CI_JOB_URL:-}"
        echo "pipeline:  ${CI_PIPELINE_ID}"
        echo "commit:    ${CI_COMMIT_SHA:-} (${CI_COMMIT_REF_NAME:-})"
        echo "runner:    $(hostname)"
        echo "collected: $(date '+%F %T %Z')"
        echo "vms:       ${ALL_VM_NAMES}"
        echo "scenarios: ${SCENARIOS_TO_RUN}"
    } > "${out_dir}/job-summary.txt"

    timeout 30 df -h > "${out_dir}/df.txt" 2>&1 || true
    timeout 30 free -m > "${out_dir}/free.txt" 2>&1 || true
    timeout 30 virsh list --all > "${out_dir}/virsh-list.txt" 2>&1 || true

    local prefix="vagrant-${CI_COMMIT_REF_SLUG-${USER}}-"
    for dom in $(virsh list --all --name 2>/dev/null | grep -F "${prefix}" || true); do
        collect_domain_diagnostics "${dom}" "${out_dir}"
    done
}

collect_domain_diagnostics() {
    local dom=$1
    local dom_dir="$2/${dom}"
    mkdir -p "${dom_dir}"
    {
        timeout 30 virsh domstate --domain "${dom}" --reason
        timeout 30 virsh domblklist --domain "${dom}"
        timeout 30 virsh domifaddr --domain "${dom}" --source lease
    } > "${dom_dir}/domain-state.txt" 2>&1 || true
    timeout 30 virsh dumpxml --domain "${dom}" > "${dom_dir}/domain.xml" 2>&1 || true
    # a panic or an fsck prompt shows on the console and in no log file
    timeout 30 virsh screenshot --domain "${dom}" --file "${dom_dir}/console.ppm" \
        >/dev/null 2>&1 || rm -f "${dom_dir}/console.ppm"
    # qemu's own log: guest panic, disk errors, OOM kill of the qemu process
    if ! timeout 30 cat "/var/log/libvirt/qemu/${dom}.log" > "${dom_dir}/qemu.log" 2>/dev/null; then
        sudo -n timeout 30 cat "/var/log/libvirt/qemu/${dom}.log" \
             > "${dom_dir}/qemu.log" 2>/dev/null || rm -f "${dom_dir}/qemu.log"
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
    prepare_cluster) prepare_cluster ;;
    run_tests) time_phase "Run scenarios: ${SCENARIOS_TO_RUN}" run_tests ;;
    destroy) destroy ;;
    teardown) teardown ;;
    *) die "Wrong argument"
esac
