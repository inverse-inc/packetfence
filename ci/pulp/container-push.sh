#!/bin/bash
# Push this pipeline's service images to the registry on PF_PACKAGE_ORIGIN (deploy_containers):
# tested devel/maintenance images under their branch tags, after the GitHub promotion, and release
# images under their vX.Y.Z tag. The runner copies them, Pulp fetches nothing. The ci-docker
# account's username and password come from Psono.
# Usage: container-push.sh <source image tag> <destination tags, comma-separated>
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"

# Only from a protected ref: a release tag vX.Y.Z, or tested devel and real maintenance/X.Y pipelines.
[[ ${CI_COMMIT_REF_PROTECTED:-false} == true ]] || { echo 'Container push requires a protected ref' >&2; exit 1; }
source_tag=${1:?source image tag}
tags=${2:?comma-separated destination tags}
if [[ -n ${CI_COMMIT_TAG:-} ]]; then
    [[ $CI_COMMIT_TAG =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ && $source_tag == "$CI_COMMIT_TAG" && $tags == "$CI_COMMIT_TAG" ]] || {
        echo 'A tag pipeline pushes only its own vX.Y.Z release tag' >&2; exit 1;
    }
else
    [[ ( ${CI_COMMIT_BRANCH:-} == devel ||
        ( ${CI_COMMIT_BRANCH:-} =~ ^maintenance/[0-9]+\.[0-9]+$ && ${CI_COMMIT_BRANCH} != maintenance/99.9 ) ) ]] || {
        echo 'Container push requires devel or a real maintenance/X.Y branch' >&2; exit 1;
    }
    case ${CI_PIPELINE_SOURCE:-} in
        web|api|schedule) ;;
        push) [[ $CI_COMMIT_BRANCH == devel ]] || { echo 'Maintenance push requires web/API/schedule' >&2; exit 1; } ;;
        *) echo 'Unsupported pipeline source for container push' >&2; exit 1 ;;
    esac
    for tag in ${tags//,/ }; do
        [[ $tag =~ ^(devel|latest|maintenance-[0-9]+-[0-9]+)$ ]] || { echo "Refusing tag $tag" >&2; exit 1; }
    done
fi
: "${PF_PACKAGE_ORIGIN:?}"
[[ $PF_PACKAGE_ORIGIN =~ ^https://([a-zA-Z0-9.-]+(:[0-9]+)?)$ ]] || { echo 'PF_PACKAGE_ORIGIN must be an HTTPS origin' >&2; exit 1; }
registry=${BASH_REMATCH[1]}
username=$(bash ci/pulp/psono-field.sh "${PSONO_CI_PULP_DOCKER_ID:?}" username)
password=$(bash ci/pulp/psono-field.sh "$PSONO_CI_PULP_DOCKER_ID" password)
source=ghcr.io/inverse-inc/packetfence
destination=$registry/inverse-inc/packetfence

# The password goes through a private temporary file, never on a command line.
auth=$(mktemp)
trap 'rm -f "$auth"' EXIT
printf '%s' "$password" | skopeo login --authfile "$auth" --username "$username" --password-stdin "$registry" >/dev/null

pushed=0
for image in $(python3 -c 'import json; print(" ".join(json.load(open("ci/pulp/container-images.json"))["images"]))'); do
    # Read anonymously: an image that is not public on GHCR never reaches the registry. Images
    # without this pipeline's tag (builders, tools) are not part of this release.
    if ! error=$(skopeo inspect --raw "docker://$source/$image:$source_tag" 2>&1 >/dev/null); then
        if grep -qiE 'denied|unauthorized|authentication required' <<<"$error"; then
            echo "$image: not public on GHCR (private or not created yet), skipped"
        fi
        continue
    fi
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
