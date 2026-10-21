#!/bin/bash
# Runs inside the vagrant-build container (started by vagrant-in-docker.sh):
# packer box build via make, then optional upload to Linode Object Storage.
set -o errexit -o nounset -o pipefail

TARGET="${1:?usage: build-in-container.sh <make-target> (e.g. pfbox, pfadbox)}"

IMG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The repo is bind-mounted: hand files written as root (results, downloaded
# vagrant key) back to the host owner so the runner can clean them up.
chown_back() {
  local targets=("${IMG_DIR}")
  [[ -n "${RESULT_DIR:-}" && -e "${RESULT_DIR:-}" ]] && targets+=("${RESULT_DIR}")
  chown -R --reference="${IMG_DIR}" "${targets[@]}" 2>/dev/null || true
}
trap chown_back EXIT

make -e -C "${IMG_DIR}" "${TARGET}"

if [[ "${UPLOAD_BOX:-no}" == "yes" ]]; then
  RESULT_DIR="${RESULT_DIR:-${IMG_DIR}/results}" "${IMG_DIR}/upload-to-linode.sh"
fi
