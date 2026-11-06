#!/bin/bash
# Publish CI packages to the packaging Pulp through its API (PF_PULP_PUBLISH=yes).
#   ppa       public/        -> gitlab/<pipeline>/      every pipeline, for the CI tests (pruned after 3 days)
#   branches  public/debian  -> debian-branches/<X.Y>/  feature branches with publish_ppa=yes
#   release   public/debian  -> debian/<X.Y>/           maintenance/X.Y and devel, after the tests
# X.Y comes from conf/pf-release. File trees are merged (newest build of each package wins) and
# re-signed here; a native Pulp APT repo (e.g. 15.2) gets the .debs and signs its own index.
# Secret values must never be traced.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
MODE=${1:?ppa, branches or release}
[[ "$MODE" == ppa || "$MODE" == branches || "$MODE" == release ]] || exit 2
: "${PULP_URL:?}" "${PULP_USERNAME:?}" "${PULP_PASSWORD:?}" "${PF_PACKAGE_ORIGIN:?}" "${CI_PIPELINE_ID:?}"
[[ "$PF_PACKAGE_ORIGIN" =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?$ ]] || { echo 'PF_PACKAGE_ORIGIN must be an HTTPS origin' >&2; exit 1; }
[[ "$CI_PIPELINE_ID" =~ ^[1-9][0-9]*$ ]] || exit 2
PUBLIC_DIR=${PUBLIC_DIR:-public}
[[ -f "$PUBLIC_DIR/GPG_PUBLIC_KEY" && -d "$PUBLIC_DIR/debian" ]] || { echo "Run generate-pages first ($PUBLIC_DIR)" >&2; exit 1; }
# Fail before any upload if the vendored helper snapshot was edited.
(cd ci/pulp/vendor && sha256sum --check --quiet SHA256SUMS)
helper=ci/pulp/vendor/pipeline_repository.py

if [[ "$MODE" == ppa ]]; then
    python3 "$helper" publish --repository "${PF_PULP_GITLAB_REPOSITORY:-gitlab}" --pipeline "$CI_PIPELINE_ID" \
        --tree "$PUBLIC_DIR" --no-lock --apply --output pulp-publication.json
    printf 'PF_PPA_URL=%s/downloads/PacketFence/gitlab/%s\n' "$PF_PACKAGE_ORIGIN" "$CI_PIPELINE_ID" > pulp.env
    exit 0
fi

release=$(sed -nE 's/^PacketFence ([0-9]+\.[0-9]+)\.[0-9]+.*$/\1/p' conf/pf-release)
[[ -n "$release" ]] || { echo 'Cannot determine PacketFence release' >&2; exit 1; }
dashed=${release/./-}
if [[ "$MODE" == branches ]]; then
    tree=debian-branches; repository="debian-branches-$dashed"
else
    tree=debian; repository="debian-$dashed"
    # A native APT repository for this release takes the .debs; Pulp signs its own index.
    native="packetfence-$dashed-bookworm"
    found=$(cd ci/pulp/vendor && python3 -c 'import os, sys
from pulp_publish import API, Pulp
c = Pulp(os.environ["PULP_URL"], os.environ["PULP_USERNAME"], os.environ["PULP_PASSWORD"])
print(c.request("GET", API + "repositories/deb/apt/", params={"name": sys.argv[1]})["count"])' "$native")
    if [[ "$found" == 1 ]]; then
        mapfile -t debs < <(find "$PUBLIC_DIR/debian/pool" -type f -name '*.deb' | sort)
        (( ${#debs[@]} )) || { echo 'No .deb in the generated tree' >&2; exit 1; }
        python3 ci/pulp/vendor/pulp_publish.py deb "$native" "${debs[@]}" \
            --codename bookworm --component bookworm --release "$release" > pulp-release.json
        echo "Published ${#debs[@]} packages to $PF_PACKAGE_ORIGIN/downloads/PacketFence/debian/$release (native)"
        exit 0
    fi
fi
: "${GPG_KEY_FINGERPRINT:?Set the approved signing fingerprint explicitly}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
python3 "$helper" merge-apt --repository "$repository" --tree "$PUBLIC_DIR/debian" \
    --content-url "$PF_PACKAGE_ORIGIN/downloads/PacketFence/$tree/$release" \
    --work "$work" --apply --output "pulp-$MODE.json"
echo "Published to $PF_PACKAGE_ORIGIN/downloads/PacketFence/$tree/$release"
