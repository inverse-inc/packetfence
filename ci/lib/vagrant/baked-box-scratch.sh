#!/bin/bash
# Sourced by setup-vagrant-box.sh. Lock the directory inode itself so cleanup
# never creates/replaces a lock file while another process is using it.

create_baked_box_work_dir() {
    local root=$1
    mkdir -p "${root}"
    WORK_DIR=$(mktemp -d "${root}/download.XXXXXXXXXX")
    exec {BAKED_BOX_WORK_FD}<"${WORK_DIR}"
    flock -n "${BAKED_BOX_WORK_FD}"
    # A process suspended between mktemp and flock may have been swept.
    # Do not start a download unless its directory still exists.
    test -d "${WORK_DIR}"
    # Hold the lock through cleanup; descendants inherit it so a surviving
    # downloader still protects its files if the parent shell is killed.
    trap 'rm -rf -- "${WORK_DIR}"' EXIT
}

sweep_baked_box_work_dirs() {
    local root=$1 dir
    [ -d "${root}" ] || return 0
    # Only directories created with the locking protocol are eligible.
    # Legacy tmp.* directories may belong to older, non-locking jobs.
    while IFS= read -r -d '' dir; do
        (
            exec {scratch_fd}<"${dir}" || exit 0
            flock -n "${scratch_fd}" || exit 0
            echo "===> Removing abandoned box download dir ${dir}"
            rm -rf -- "${dir}"
        )
    done < <(find "${root}" -mindepth 1 -maxdepth 1 -type d \
        -name 'download.*' -mmin +60 -print0)
}
