#!/bin/bash
# Push this pipeline's tested service images to packages.packetfence.com under their branch tags
# (deploy_containers, after the GitHub promotion): the runner copies them, Pulp fetches nothing.
# Only ci-docker may push there (masked CI variables PF_PULP_CONTAINER_USERNAME / _PASSWORD).
# Usage: container-push.sh <pipeline image tag> <branch tags, comma-separated>
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"

# Only tested devel and real maintenance/X.Y pipelines, from a protected ref (as the GitHub promotion).
[[ ${CI_COMMIT_REF_PROTECTED:-false} == true ]] || { echo 'Container push requires a protected ref' >&2; exit 1; }
[[ -z ${CI_COMMIT_TAG:-} && ( ${CI_COMMIT_BRANCH:-} == devel ||
    ( ${CI_COMMIT_BRANCH:-} =~ ^maintenance/[0-9]+\.[0-9]+$ && ${CI_COMMIT_BRANCH} != maintenance/99.9 ) ) ]] || {
    echo 'Container push requires devel or a real maintenance/X.Y branch' >&2; exit 1;
}
case ${CI_PIPELINE_SOURCE:-} in
    web|api|schedule) ;;
    push) [[ $CI_COMMIT_BRANCH == devel ]] || { echo 'Maintenance push requires web/API/schedule' >&2; exit 1; } ;;
    *) echo 'Unsupported pipeline source for container push' >&2; exit 1 ;;
esac
source_tag=${1:?pipeline image tag}
tags=${2:?comma-separated branch tags}
for tag in ${tags//,/ }; do
    [[ $tag =~ ^(devel|latest|maintenance-[0-9]+-[0-9]+)$ ]] || { echo "Refusing tag $tag" >&2; exit 1; }
done
: "${PF_PULP_CONTAINER_USERNAME:?}" "${PF_PULP_CONTAINER_PASSWORD:?}"
registry=${PF_CONTAINER_REGISTRY:-packages.packetfence.com}
source=ghcr.io/inverse-inc/packetfence
destination=$registry/inverse-inc/packetfence

# The password goes through a private temporary file, never on a command line.
auth=$(mktemp)
trap 'rm -f "$auth"' EXIT
printf '%s' "$PF_PULP_CONTAINER_PASSWORD" \
    | skopeo login --authfile "$auth" --username "$PF_PULP_CONTAINER_USERNAME" --password-stdin "$registry" >/dev/null

pushed=0
for image in $(python3 -c 'import json; print(" ".join(json.load(open("ci/pulp/container-images.json"))["images"]))'); do
    # Images without this pipeline's tag (builders, tools) are not part of this release.
    skopeo inspect --raw "docker://$source/$image:$source_tag" >/dev/null 2>&1 || continue
    for tag in ${tags//,/ }; do
        # Same manifests and digests as on GitHub, every architecture.
        skopeo copy --all --preserve-digests --retry-times 3 --dest-authfile "$auth" \
            "docker://$source/$image:$source_tag" "docker://$destination/$image:$tag"
        echo "pushed $destination/$image:$tag"
        pushed=$((pushed + 1))
    done
done
[ "$pushed" -gt 0 ] || { echo "No image carries the pipeline tag $source_tag" >&2; exit 1; }
echo "$pushed image tags pushed to $registry"
