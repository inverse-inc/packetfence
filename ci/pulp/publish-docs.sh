#!/bin/bash
# Publish the built guides (build_artifacts_doc: docs/*.html, docs/*.pdf, docs/images/, docs/styles/*.min.css) to
# the packaging Pulp: doc-X-Y-0, served at /downloads/PacketFence/doc/X.Y.0/ (X.Y from conf/pf-release). The
# snapshot then holds exactly this build. The ci-docs account; secret values must never be traced.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
: "${PF_PACKAGE_ORIGIN:?}"
[[ "$PF_PACKAGE_ORIGIN" =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?$ ]] || { echo 'PF_PACKAGE_ORIGIN must be an HTTPS origin' >&2; exit 1; }
PULP_USERNAME=$(bash ci/pulp/psono-field.sh "${PSONO_CI_PULP_DOCS_ID:?}" username)
PULP_PASSWORD=$(bash ci/pulp/psono-field.sh "$PSONO_CI_PULP_DOCS_ID" password)
export PULP_URL=$PF_PACKAGE_ORIGIN PULP_USERNAME PULP_PASSWORD
# Fail before any upload if the vendored helper snapshot was edited.
(cd ci/pulp/vendor && sha256sum --check --quiet SHA256SUMS)
release=$(sed -nE 's/^PacketFence ([0-9]+\.[0-9]+)\.[0-9]+.*$/\1/p' conf/pf-release)
[[ -n "$release" ]] || { echo 'Cannot determine PacketFence release' >&2; exit 1; }

# The guides with their images and styles, laid out as they reference them (images/, styles/).
tree=$(mktemp -d)
trap 'rm -rf "$tree"' EXIT
shopt -s nullglob
guides=(docs/*.html docs/*.pdf)
(( ${#guides[@]} )) || { echo 'No built guide in docs/ (build_artifacts_doc)' >&2; exit 1; }
cp -- "${guides[@]}" "$tree/"
[[ -d docs/images ]] && cp -R docs/images "$tree/images"
styles=(docs/styles/*.min.css)
if (( ${#styles[@]} )); then
    mkdir "$tree/styles"
    cp -- "${styles[@]}" "$tree/styles/"
fi
python3 ci/pulp/vendor/pipeline_repository.py publish-docs --repository "doc-${release/./-}-0" \
    --tree "$tree" --apply --output pulp-docs.json
echo "Published to $PF_PACKAGE_ORIGIN/downloads/PacketFence/doc/$release.0/"
