#!/bin/bash
# Maps CI_COMMIT_REF_NAME → devel | maintenance | branches. Mirrored in
# addons/vagrant/pfservers/Vagrantfile so bake and test resolve the same box.

vagrant_box_category() {
    local ref="${CI_COMMIT_REF_NAME:-}"
    if [ "${ref}" = "devel" ]; then
        echo "devel"
    elif [[ "${ref}" =~ ^maintenance/[0-9]+\.[0-9]+$ ]]; then
        echo "maintenance"
    else
        echo "branches"
    fi
}
