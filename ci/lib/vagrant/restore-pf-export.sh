#!/bin/bash
set -o nounset -o pipefail -o errexit

# Standalone wrapper around addons/vagrant/playbooks/restore_pf_export.yml
# for manual / local use. CI consumes the playbook directly via
# import_playbook in each scenario's site.yml — the playbook is
# self-contained (localhost rclone download + pfservers push/import).
#
# Required env vars:
#   CI_PIPELINE_ID
#   PF_EXPORT_ARCH           deb12 | el8 (must match the export key suffix)
#   RCLONE_LINODE_URL
#   RCLONE_ACCESS_KEY_ID
#   RCLONE_SECRET_ACCESS_KEY
#
# Optional env vars:
#   VAGRANT_DIR              (default: ${CI_PROJECT_DIR}/addons/vagrant)
#   ANSIBLE_VM_LIST          host pattern (default: pfservers)

VAGRANT_DIR=${VAGRANT_DIR:-${CI_PROJECT_DIR:-.}/addons/vagrant}
ANSIBLE_VM_LIST=${ANSIBLE_VM_LIST:-pfservers}

if [ -z "${CI_PIPELINE_ID:-}" ]; then
    echo "ERROR: CI_PIPELINE_ID must be set"
    exit 1
fi

echo "===> restore-pf-export.sh"
echo "     VAGRANT_DIR     = ${VAGRANT_DIR}"
echo "     ANSIBLE_VM_LIST = ${ANSIBLE_VM_LIST}"

(
    cd "${VAGRANT_DIR}"
    ansible-playbook playbooks/restore_pf_export.yml -l "localhost,${ANSIBLE_VM_LIST}"
)

echo "===> Restore complete"
