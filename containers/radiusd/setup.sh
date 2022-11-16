#!/usr/bin/bash

# Quit on error.
set -e
# Treat undefined variables as errors.
set -u


function main {
    local pf_uid="${1:-}"
    local pf_gid="${2:-}"

    # Change the uid
    if [[ -n "${pf_uid:-}" ]]; then
        usermod -u "${pf_uid}" pf
    fi
    # Change the gid
    if [[ -n "${pf_gid:-}" ]]; then
        groupmod -g "${pf_gid}" pf
    fi

    # Setup permissions on the run directory where the sockets will be
    # created, so we are sure the app will have the rights to create them.

    # Make sure the folder exists.
    #mkdir /usr/local/pf/var/run/
    # Set owner.
    chown root:pf /usr/local/pf/var/run/
    # Set permissions.
    chmod u=rwX,g=rwX,o=--- /usr/local/pf/var/run/
}
