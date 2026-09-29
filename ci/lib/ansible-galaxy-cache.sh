#!/bin/bash
# Source to select dependencies in the current shell, or run as:
# bash ansible-galaxy-cache.sh requirements.yml ansible.cfg command [args...]

_ANSIBLE_GALAXY_CACHE_HELPER=$(realpath "${BASH_SOURCE[0]}")

_install_ansible_galaxy_cache() (
    set -euo pipefail
    local requirements=$1 cache=$2 staging attempt
    mkdir -p "$(dirname "${cache}")"
    # Concurrent jobs installing the same requirements share one completed entry.
    exec 9>"${cache}.lock"
    flock 9
    [[ -f "${cache}/.complete" ]] && exit 0

    staging=$(mktemp -d "${cache}.tmp.XXXXXX")
    trap 'rm -rf "${staging}"' EXIT
    mkdir -p "${staging}/roles" "${staging}/collections"
    export ANSIBLE_ROLES_PATH="${staging}/roles"
    export ANSIBLE_COLLECTIONS_PATH="${staging}/collections"
    # ansible-core 2.14 (Bookworm) uses the plural name.
    export ANSIBLE_COLLECTIONS_PATHS="${ANSIBLE_COLLECTIONS_PATH}"

    for attempt in 1 2 3; do
        if ansible-galaxy role install -r "${requirements}" -p "${ANSIBLE_ROLES_PATH}" &&
           ansible-galaxy collection install -r "${requirements}" -p "${ANSIBLE_COLLECTIONS_PATH}"; then
            touch "${staging}/.complete"
            mv -T "${staging}" "${cache}"
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
    local requirements config cache_root digest cache seed
    requirements=$(realpath "${1:?requirements file required}") || return
    config=$(realpath "${2:?ansible.cfg required}") || return
    digest=$(sha256sum "${requirements}") || return
    digest=${digest%% *}
    cache_root=${ANSIBLE_GALAXY_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/packetfence/ansible-galaxy}
    cache_root=$(realpath -m "${cache_root}") || return
    cache="${cache_root}/v1/${digest}"
    export ANSIBLE_CONFIG="${config}"

    # Builder images can supply immutable entries without copying or downloading.
    seed="${ANSIBLE_GALAXY_SEED_DIR:-/opt/packetfence/ansible-galaxy}/v1/${digest}"
    if [[ ! -f "${cache}/.complete" && -f "${seed}/.complete" ]]; then
        cache=${seed}
    elif [[ ! -f "${cache}/.complete" ]]; then
        # A separate Bash process preserves errexit even when the caller checks
        # this function's return status with an if/&&/|| expression.
        bash "${_ANSIBLE_GALAXY_CACHE_HELPER}" --install "${requirements}" "${cache}" || return
    fi
    export ANSIBLE_ROLES_PATH="${cache}/roles"
    export ANSIBLE_COLLECTIONS_PATH="${cache}/collections"
    export ANSIBLE_COLLECTIONS_PATHS="${ANSIBLE_COLLECTIONS_PATH}"
    echo "Using Ansible dependencies: ${cache}" >&2
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    if [[ ${1:-} == --install ]]; then
        _install_ansible_galaxy_cache "$2" "$3"
    else
        prepare_ansible_dependencies "$1" "$2"
        shift 2
        exec "${@:?command required}"
    fi
fi
