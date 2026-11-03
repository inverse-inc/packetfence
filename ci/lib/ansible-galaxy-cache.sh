#!/bin/bash
# Source to select dependencies in the current shell, or run as:
# bash ansible-galaxy-cache.sh requirements.yml ansible.cfg command [args...]

_ANSIBLE_GALAXY_CACHE_HELPER=$(realpath "${BASH_SOURCE[0]}")

_ansible_galaxy_refresh_id() {
    if [[ ${GALAXY_FORCE:-no} == yes && -z ${PF_ANSIBLE_GALAXY_REFRESH_ID:-} ]]; then
        export PF_ANSIBLE_GALAXY_REFRESH_ID="$$-$(date +%s%N)"
    fi
}
# Initialize before a sourcing script forks any phase subprocesses.
_ansible_galaxy_refresh_id

_install_ansible_galaxy_cache() (
    set -euo pipefail
    local requirements=$1 cache=$2 refresh_id=$3 staging generation link attempt
    mkdir -p "${cache}"
    # Concurrent jobs installing the same requirements share one completed entry.
    exec 9>"${cache}/.lock"
    flock 9
    if [[ -f "${cache}/current/.complete" ]] &&
       { [[ -z ${refresh_id} ]] || [[ $(cat "${cache}/current/.complete") == "${refresh_id}" ]]; }; then
        exit 0
    fi

    staging=$(mktemp -d "${cache}/.tmp.XXXXXX")
    generation="${cache}/generation.${staging##*.}"
    link="${cache}/.current.${staging##*.}"
    trap 'rm -rf "${staging}"; rm -f "${link}"' EXIT
    mkdir -p "${staging}/roles" "${staging}/collections"
    export ANSIBLE_ROLES_PATH="${staging}/roles"
    export ANSIBLE_COLLECTIONS_PATH="${staging}/collections"
    # ansible-core 2.14 (Bookworm) uses the plural name.
    export ANSIBLE_COLLECTIONS_PATHS="${ANSIBLE_COLLECTIONS_PATH}"

    for attempt in 1 2 3; do
        if ansible-galaxy role install -r "${requirements}" -p "${ANSIBLE_ROLES_PATH}" &&
           ansible-galaxy collection install -r "${requirements}" -p "${ANSIBLE_COLLECTIONS_PATH}"; then
            printf '%s\n' "${refresh_id}" > "${staging}/.complete"
            mv -T "${staging}" "${generation}"
            # Publish a new generation without modifying files used by readers.
            ln -s "$(basename "${generation}")" "${link}"
            mv -Tf "${link}" "${cache}/current"
            exit 0
        fi
        if [[ ${attempt} -lt 3 ]]; then
            echo "Galaxy installation failed; retrying in 10 seconds (${attempt}/3)" >&2
            sleep 10
        fi
    done
    exit 1
)

prepare_ansible_dependencies() {
    local requirements config cache_root digest cache seed version refresh_id=
    requirements=$(realpath "${1:?requirements file required}") || return
    config=$(realpath "${2:?ansible.cfg required}") || return
    export ANSIBLE_CONFIG="${config}"
    # Capture all output before extracting the header: head can cause SIGPIPE,
    # and a failed version query must not silently produce a usable cache key.
    version=$(ansible-galaxy --version) || return
    version=${version%%$'\n'*}
    [[ -n ${version} ]] || { echo "Missing Ansible Galaxy version" >&2; return 1; }
    digest=$(sha256sum "${requirements}") || return
    digest=${digest%% *}
    digest=$(printf '%s\n%s\n' "${digest}" "${version}" | sha256sum) || return
    digest=${digest%% *}
    cache_root=${ANSIBLE_GALAXY_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/packetfence/ansible-galaxy}
    cache_root=$(realpath -m "${cache_root}") || return
    cache="${cache_root}/v2/${digest}"
    if [[ ${GALAXY_FORCE:-no} == yes ]]; then
        # Inherit this token in phase subprocesses so one workflow refreshes
        # each dependency set once, even when provisioning multiple VMs.
        _ansible_galaxy_refresh_id
        refresh_id=${PF_ANSIBLE_GALAXY_REFRESH_ID}
    fi

    # Builder images can supply immutable entries without copying or downloading.
    seed="${ANSIBLE_GALAXY_SEED_DIR:-/opt/packetfence/ansible-galaxy}/v2/${digest}"
    if [[ -z ${refresh_id} && ! -f "${cache}/current/.complete" && -f "${seed}/current/.complete" ]]; then
        cache=${seed}
    elif [[ -n ${refresh_id} || ! -f "${cache}/current/.complete" ]]; then
        # A separate Bash process preserves errexit even when the caller checks
        # this function's return status with an if/&&/|| expression.
        bash "${_ANSIBLE_GALAXY_CACHE_HELPER}" --install "${requirements}" "${cache}" "${refresh_id}" || return
    fi
    # Pin this process to the immutable generation, never the moving symlink.
    cache=$(realpath -e "${cache}/current") || return
    export ANSIBLE_ROLES_PATH="${cache}/roles"
    export ANSIBLE_COLLECTIONS_PATH="${cache}/collections"
    export ANSIBLE_COLLECTIONS_PATHS="${ANSIBLE_COLLECTIONS_PATH}"
    echo "Using Ansible dependencies: ${cache}" >&2
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    if [[ ${1:-} == --install ]]; then
        _install_ansible_galaxy_cache "$2" "$3" "$4"
    else
        prepare_ansible_dependencies "$1" "$2"
        shift 2
        exec "${@:?command required}"
    fi
fi
