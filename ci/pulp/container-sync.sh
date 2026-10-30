#!/bin/bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
[[ ${PF_PULP_CONTAINER_SYNC_ENABLED:-no} == yes ]] || exit 0
[[ ${CI_COMMIT_REF_PROTECTED:-false} == true ]] || { echo 'Container sync requires a protected ref' >&2; exit 1; }
[[ -z ${CI_COMMIT_TAG:-} && ( ${CI_COMMIT_BRANCH:-} == devel ||
    ( ${CI_COMMIT_BRANCH:-} =~ ^maintenance/[0-9]+\.[0-9]+$ && ${CI_COMMIT_BRANCH} != maintenance/99.9 ) ) ]] || {
    echo 'Container sync requires devel or a real maintenance/X.Y branch' >&2; exit 1;
}
case ${CI_PIPELINE_SOURCE:-} in
    web|api|schedule) ;;
    push) [[ $CI_COMMIT_BRANCH == devel ]] || { echo 'Maintenance sync requires web/API/schedule' >&2; exit 1; } ;;
    *) echo 'Unsupported pipeline source for container sync' >&2; exit 1 ;;
esac
: "${PF_PULP_CONTAINER_USERNAME:?}" "${PF_PULP_CONTAINER_PASSWORD:?}" "${PULP_URL:?}"
# A separate account can sync approved remotes and publish versions, but cannot upload packages.
export PULP_USERNAME="$PF_PULP_CONTAINER_USERNAME" PULP_PASSWORD="$PF_PULP_CONTAINER_PASSWORD"
(cd ci/pulp/vendor && sha256sum --check SHA256SUMS)
helper=ci/pulp/vendor/container_mirror.py
python3 "$helper" plan --catalog ci/pulp/container-images.json --branch "$CI_COMMIT_BRANCH" --output container-plan.json
args=(sync --plan container-plan.json --output container-publication.json --apply)
if [[ ${PF_PULP_CONTAINER_ALLOW_TAG_UPDATE:-no} == yes ]]; then args+=(--allow-tag-update); fi
python3 "$helper" "${args[@]}"
