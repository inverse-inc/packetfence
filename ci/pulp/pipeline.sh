#!/bin/bash
# Opt-in public pipeline repositories. Secret values must never be traced.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
MODE=${1:?prepare or publish}
[[ "$MODE" == prepare || "$MODE" == publish ]] || exit 2
[[ ${PF_PULP_ENABLED:-no} == yes ]] || { echo 'Pulp is not enabled' >&2; exit 1; }
[[ ${CI_COMMIT_REF_PROTECTED:-false} == true ]] || { echo 'Pulp publication requires a trusted protected ref' >&2; exit 1; }
: "${PULP_URL:?}" "${PULP_USERNAME:?}" "${PULP_PASSWORD:?}" "${PULP_CONTENT_ORIGIN:?}"
: "${PF_PULP_REPOSITORY:?}" "${PF_PACKAGE_ORIGIN:?}" "${CI_PIPELINE_ID:?}"
: "${PF_PACKAGE_ENVIRONMENT:?staging or production}" "${PF_PACKAGE_BACKUP_BUCKET:?}"
: "${PF_PACKAGE_BACKUP_ENDPOINT:?}" "${PF_PACKAGE_BACKUP_REGION:?}" "${PF_PACKAGE_BACKUP_PREFIX:?}"
: "${AWS_ACCESS_KEY_ID:?}" "${AWS_SECRET_ACCESS_KEY:?}"
[[ "$PF_PACKAGE_ENVIRONMENT" == staging || "$PF_PACKAGE_ENVIRONMENT" == production ]] || exit 2
release=$(sed -nE 's/^PacketFence ([0-9]+\.[0-9]+)\.[0-9]+.*$/\1/p' conf/pf-release)
[[ -n "$release" ]] || { echo 'Cannot determine PacketFence release' >&2; exit 1; }
[[ "$PF_PACKAGE_ORIGIN" =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?$ ]] || { echo 'PF_PACKAGE_ORIGIN must be an HTTPS origin' >&2; exit 1; }
[[ "$CI_PIPELINE_ID" =~ ^[1-9][0-9]*$ ]] || exit 2
export PPA_URL="$PF_PACKAGE_ORIGIN/downloads/PacketFence/gitlab/$CI_PIPELINE_ID"
export RESULT_DIR=${RESULT_DIR:-result}
export PUBLIC_DIR=pulp-public
export PPA_DEPENDENCIES_DIR=pulp-dependencies
export APT_ARCHITECTURES='amd64 source'
export PF_PULP_LOCK=pipeline-lock.json
helper=ci/pulp/vendor/pipeline_repository.py
# Fail before any publishing or secret retrieval if the helper snapshot was edited.
(cd ci/pulp/vendor && sha256sum --check SHA256SUMS)
if [[ "$MODE" == prepare ]]; then
    : "${PF_PULP_BASES_FILE:?Protected GitLab file variable containing the operator base policy}"
    base=${PF_PULP_BASE:-}
    if [[ -z "$base" ]]; then
        case ${CI_COMMIT_REF_NAME:-} in
            devel) base="devel-$release" ;;
            maintenance/"$release") base="maintenance-$release" ;;
            *) echo 'Set PF_PULP_BASE explicitly for a feature branch or release tag' >&2; exit 1 ;;
        esac
    fi
    args=(lock --policy "$PF_PULP_BASES_FILE" --release "$release" --base "$base" --output "$PF_PULP_LOCK")
    if [[ -n ${PF_PULP_OVERRIDES:-} ]]; then args+=(--overrides "$PF_PULP_OVERRIDES"); fi
    python3 "$helper" "${args[@]}"
    python3 - <<'CONTEXT'
import json, os
from pathlib import Path
p = Path('pipeline-lock.json')
lock = json.loads(p.read_text())
if set(lock['targets']) != {'debian/bookworm', 'centos/8'}:
    raise SystemExit('Both Debian bookworm and EL8 dependency targets are required')
lock['pipeline'] = os.environ['CI_PIPELINE_ID']
lock['commit'] = os.environ['CI_COMMIT_SHA']
p.write_text(json.dumps(lock, sort_keys=True, indent=2) + '\n')
CONTEXT
    python3 "$helper" fetch --lock "$PF_PULP_LOCK" --output "$PPA_DEPENDENCIES_DIR"
    export RESULT_DIR=pulp-empty-result
    mkdir -p "$RESULT_DIR"
    export PPA_URL="$PPA_URL/dependencies"
else
    [[ -s "$PF_PULP_LOCK" ]] || { echo 'Missing lock from prepare_pulp_dependencies; refusing to re-resolve' >&2; exit 1; }
    python3 ci/pulp/check-lock.py "$PF_PULP_LOCK"
    python3 "$helper" fetch --lock "$PF_PULP_LOCK" --output "$PPA_DEPENDENCIES_DIR" --built "$RESULT_DIR"
fi
# Metadata is signed by the same explicit key as the old PPA generator.
: "${PSONO_API_KEY_ID:?}" "${PSONO_API_KEY_SECRET_KEY:?}" "${PSONO_GPG_PRIVATE_KEY_SECRET_ID:?}"
python3 addons/packetfence-perl/psono.py \
    --api_key_id="$PSONO_API_KEY_ID" --api_key_secret_key="$PSONO_API_KEY_SECRET_KEY" \
    --secret_id="$PSONO_GPG_PRIVATE_KEY_SECRET_ID" --return_value=password_notes \
    | gpg --batch --pinentry-mode loopback --import
: "${GPG_KEY_FINGERPRINT:?Set the approved signing fingerprint explicitly}"
bash ci/scripts/generate-pages.sh
cp "$PF_PULP_LOCK" "$PUBLIC_DIR/pipeline-lock.json"
cp "$PPA_DEPENDENCIES_DIR/selection.json" "$PUBLIC_DIR/dependency-selection.json"
if [[ "$MODE" == publish ]]; then
    # Check both package managers before exposing the new final repository.
    bash ci/pulp/validate-repository.sh "$PUBLIC_DIR"
fi
# Archive the exact signed tree before switching Pulp's publication. Both phases
# share the CI writer lock; unchanged package bytes are reused across catalogs.
phase=packages
if [[ "$MODE" == prepare ]]; then phase=dependencies; fi
python3 ci/pulp/vendor/archive_ci_packages.py \
    --tree "$PUBLIC_DIR" --environment "$PF_PACKAGE_ENVIRONMENT" \
    --pipeline "$CI_PIPELINE_ID" --release "$release" --phase "$phase" \
    --bucket "$PF_PACKAGE_BACKUP_BUCKET" --endpoint "$PF_PACKAGE_BACKUP_ENDPOINT" \
    --region "$PF_PACKAGE_BACKUP_REGION" --prefix "$PF_PACKAGE_BACKUP_PREFIX" \
    --output "package-backup-$phase.json" --apply
args=(publish --repository "$PF_PULP_REPOSITORY" --pipeline "$CI_PIPELINE_ID" --tree "$PUBLIC_DIR" --apply --output pulp-publication.json)
if [[ "$MODE" == prepare ]]; then args+=(--dependencies); fi
python3 "$helper" "${args[@]}"
printf 'PF_PULP_DEPENDENCY_URL=%s/downloads/PacketFence/gitlab/%s/dependencies\n' "$PF_PACKAGE_ORIGIN" "$CI_PIPELINE_ID" > pulp.env
printf 'PF_PPA_URL=%s/downloads/PacketFence/gitlab/%s\n' "$PF_PACKAGE_ORIGIN" "$CI_PIPELINE_ID" >> pulp.env
