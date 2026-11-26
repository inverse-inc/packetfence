#!/bin/bash
# Push this pipeline's service images to the registry on PF_PACKAGE_ORIGIN (deploy_containers):
# tested devel/maintenance images under their branch tags, after the GitHub promotion; a feature
# branch's under its pipeline tag. The runner copies them, Pulp fetches nothing. The ci-docker
# account's username and password come from Psono.
# Usage: container-push.sh <source image tag> <destination tags, comma-separated>
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"

# devel and real maintenance/X.Y (protected refs) push their branch tags; any other branch only its
# own pipeline tag (<slug>-p<pipeline>). A release tag pushes nothing.
source_tag=${1:?source image tag}
tags=${2:?comma-separated destination tags}
[[ -z ${CI_COMMIT_TAG:-} ]] || { echo 'A release tag keeps its images on GitHub: nothing is pushed here' >&2; exit 1; }
[[ -n ${CI_COMMIT_BRANCH:-} ]] || { echo 'Container push requires a branch pipeline' >&2; exit 1; }
if [[ $CI_COMMIT_BRANCH == devel || $CI_COMMIT_BRANCH =~ ^maintenance/[0-9]+\.[0-9]+$ ]]; then
    [[ ${CI_COMMIT_REF_PROTECTED:-false} == true ]] || { echo 'Container push requires a protected ref' >&2; exit 1; }
    [[ $CI_COMMIT_BRANCH != maintenance/99.9 ]] || { echo 'Container push requires a real maintenance/X.Y branch' >&2; exit 1; }
    # Only this branch's own tags: a pipeline variable cannot move another branch's images.
    if [[ $CI_COMMIT_BRANCH == devel ]]; then allowed='devel|latest'; else allowed=${CI_COMMIT_REF_SLUG:?}; fi
    case ${CI_PIPELINE_SOURCE:-} in
        web|api|schedule) ;;
        push) [[ $CI_COMMIT_BRANCH == devel ]] || { echo 'Maintenance push requires web/API/schedule' >&2; exit 1; } ;;
        *) echo 'Unsupported pipeline source for container push' >&2; exit 1 ;;
    esac
else
    allowed="${CI_COMMIT_REF_SLUG:?}-p${CI_PIPELINE_ID:?}"
    [[ $source_tag == "$allowed" ]] || { echo "A feature branch pushes only its pipeline tag $allowed" >&2; exit 1; }
    case ${CI_PIPELINE_SOURCE:-} in
        web|api|schedule) ;;
        *) echo 'A feature branch pushes from web/API/schedule pipelines only' >&2; exit 1 ;;
    esac
fi
for tag in ${tags//,/ }; do
    [[ $tag =~ ^($allowed)$ ]] || { echo "Refusing tag $tag" >&2; exit 1; }
done
: "${PF_PACKAGE_ORIGIN:?}"
[[ $PF_PACKAGE_ORIGIN =~ ^https://([a-zA-Z0-9.-]+(:[0-9]+)?)$ ]] || { echo 'PF_PACKAGE_ORIGIN must be an HTTPS origin' >&2; exit 1; }
registry=${BASH_REMATCH[1]}
[[ -n ${PSONO_CI_PULP_DOCKER_ID:-} ]] || { echo 'PSONO_CI_PULP_DOCKER_ID is empty: set it in the GitLab CI/CD variables, not protected (feature branches publish too)' >&2; exit 1; }
username=$(bash ci/pulp/psono-field.sh "$PSONO_CI_PULP_DOCKER_ID" username)
password=$(bash ci/pulp/psono-field.sh "$PSONO_CI_PULP_DOCKER_ID" password)
source=ghcr.io/inverse-inc/packetfence
destination=$registry/inverse-inc/packetfence

# The password goes through a private temporary file, never on a command line.
auth=$(mktemp)
trap 'rm -f "$auth"' EXIT
printf '{}' > "$auth"  # skopeo reads the auth file as JSON before writing the login
printf '%s' "$password" | skopeo login --authfile "$auth" --username "$username" --password-stdin "$registry" >/dev/null

# First every image is checked, then copied: a refusal leaves the registry untouched.
ready=()
untagged=()
for image in $(python3 -c 'import json; print(" ".join(json.load(open("ci/pulp/container-images.json"))["images"]))'); do
    # Read anonymously: an image that is not public on GHCR never reaches the registry. Images
    # without this pipeline's tag (builders, tools) are not part of this release.
    # Anything else (5xx, rate limit, network) fails: a skipped image would mix releases on the registry.
    if ! error=$(skopeo inspect --retry-times 3 --raw "docker://$source/$image:$source_tag" 2>&1 >/dev/null); then
        if grep -qiE 'manifest unknown|not found' <<<"$error"; then
            untagged+=("$image")
        elif grep -qiE 'denied|unauthorized|authentication required' <<<"$error"; then
            echo "$image: not public on GHCR (private or not created yet), skipped"
        else
            echo "$image: cannot read $source/$image:$source_tag on GHCR: $error" >&2
            exit 1
        fi
        continue
    fi
    ready+=("$image")
done
(( ${#untagged[@]} == 0 )) || echo "Without the $source_tag tag (not built by this pipeline), skipped: ${untagged[*]}"
(( ${#ready[@]} )) || { echo "No image carries the pipeline tag $source_tag" >&2; exit 1; }
# Every pipeline builds these: without them the tag would name a partial release.
for core in pfcmd radiusd; do
    [[ " ${ready[*]} " == *" $core "* ]] || { echo "$core lacks the pipeline tag $source_tag: partial build" >&2; exit 1; }
done

pushed=0
for image in "${ready[@]}"; do
    for tag in ${tags//,/ }; do
        # Same manifests and digests as on GitHub, every architecture.
        skopeo copy --all --preserve-digests --retry-times 3 --dest-authfile "$auth" \
            "docker://$source/$image:$source_tag" "docker://$destination/$image:$tag"
        echo "pushed $destination/$image:$tag"
        pushed=$((pushed + 1))
    done
done
echo "$pushed image tags pushed to $registry"
