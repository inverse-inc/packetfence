#!/bin/bash
# Publish CI packages to the packaging Pulp through its API.
#   ppa       public/                 -> gitlab/<pipeline>/                every pipeline, for the CI tests
#   branches  public/debian           -> debian/branches/<X.Y>/<pipeline>/          feature branches with DEPLOY_PKG=yes
#             public/centos/<N>       -> RHEL<N>/branches/<X.Y>/<pipeline>/x86_64/  (rhel<N>-branches-X-Y)
#   release   public/debian, suite S  -> the native X.Y repository serving S   devel, maintenance/X.Y
#             public/centos/<N>       -> native packetfence-X-Y-el<N>
#   files     result/                 -> debian/ and RHEL<N>/ file snapshots: packetfence-release/-export/
#                                        -upgrade/-ci-lib under their published names (publish-files.py)
# The OS comes from what was built: a new Debian suite or EL version only needs its repositories in Pulp.
# X.Y comes from conf/pf-release. Without a native repository (e.g. a devel version) the Debian tree is
# merged into the debian-X-Y file tree instead. Secret values must never be traced.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
MODE=${1:?ppa, branches, release or files}
[[ "$MODE" == ppa || "$MODE" == branches || "$MODE" == release || "$MODE" == files ]] || exit 2
: "${PF_PACKAGE_ORIGIN:?}" "${CI_PIPELINE_ID:?}"
[[ "$PF_PACKAGE_ORIGIN" =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?$ ]] || { echo 'PF_PACKAGE_ORIGIN must be an HTTPS origin' >&2; exit 1; }
[[ "$CI_PIPELINE_ID" =~ ^[1-9][0-9]*$ ]] || exit 2
# The ci-packages account: username and password read from Psono.
[[ -n ${PSONO_CI_PULP_PACKAGES_ID:-} ]] || { echo 'PSONO_CI_PULP_PACKAGES_ID is empty. GitLab gives the Pulp credentials to protected branches only: protect this branch, or deploy from one that is' >&2; exit 1; }
PULP_USERNAME=$(bash ci/pulp/psono-field.sh "$PSONO_CI_PULP_PACKAGES_ID" username)
PULP_PASSWORD=$(bash ci/pulp/psono-field.sh "$PSONO_CI_PULP_PACKAGES_ID" password)
export PULP_URL=$PF_PACKAGE_ORIGIN PULP_USERNAME PULP_PASSWORD
# Fail before any upload if the vendored helper snapshot was edited.
(cd ci/pulp/vendor && sha256sum --check --quiet SHA256SUMS)
helper=ci/pulp/vendor/pipeline_repository.py
release=$(sed -nE 's/^PacketFence ([0-9]+\.[0-9]+)\.[0-9]+.*$/\1/p' conf/pf-release)
[[ -n "$release" ]] || { echo 'Cannot determine PacketFence release' >&2; exit 1; }
dashed=${release/./-}

if [[ "$MODE" == files ]]; then
    exec python3 ci/pulp/publish-files.py --release "$release" --result "${RESULT_DIR:-result}"
fi

PUBLIC_DIR=${PUBLIC_DIR:-public}
[[ -f "$PUBLIC_DIR/GPG_PUBLIC_KEY" && -d "$PUBLIC_DIR/debian" ]] || { echo "Run generate-pages first ($PUBLIC_DIR)" >&2; exit 1; }
# EL versions and Debian suites this pipeline built.
mapfile -t el_versions < <(find "$PUBLIC_DIR/centos" -mindepth 2 -maxdepth 2 -type d -name x86_64 2>/dev/null \
    | sed -E 's#.*/centos/([0-9]+)/x86_64$#\1#' | sort -n)
mapfile -t suites < <(find "$PUBLIC_DIR/debian/dists" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort)

if [[ "$MODE" == ppa ]]; then
    python3 "$helper" publish --repository "${PF_PULP_GITLAB_REPOSITORY:-gitlab}" --pipeline "$CI_PIPELINE_ID" \
        --tree "$PUBLIC_DIR" --no-lock --apply --output pulp-publication.json
    exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
if [[ "$MODE" == branches ]]; then
    # A lasting copy of this pipeline's PPA (gitlab/<pipeline>/, signed by generate-pages), one folder per
    # pipeline, with the release/export/upgrade/ci-lib files under their branches names (*_DEST_NAME) and
    # pipeline.json, which the packaging side reads to keep the newest pipelines of each branch.
    : "${CI_COMMIT_REF_NAME:?}" "${CI_COMMIT_REF_SLUG:?}"
    (( ${#suites[@]} )) || { echo "No Debian suite in the generated tree" >&2; exit 1; }
    python3 ci/pulp/publish-files.py --release "$release" --result "${RESULT_DIR:-result}" --stage "$work/files"
    python3 -I - "$work/pipeline.json" "$release" <<'EOF'
import json, os, sys
from datetime import datetime, timezone
# The pipeline's creation time, not now: a retried publish must write the same bytes.
created = datetime.fromisoformat(os.environ['CI_PIPELINE_CREATED_AT'].replace('Z', '+00:00'))
created = created.astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
with open(sys.argv[1], 'w') as out:
    json.dump({'branch': os.environ['CI_COMMIT_REF_NAME'], 'slug': os.environ['CI_COMMIT_REF_SLUG'],
               'pipeline': int(os.environ['CI_PIPELINE_ID']), 'commit': os.environ.get('CI_COMMIT_SHA', ''),
               'release': sys.argv[2], 'created': created},
              out, indent=1, sort_keys=True)
EOF
    # <folder> <built tree to copy> <staged files>. Debian copies the contents of debian/ (dists/, pool/ at the
    # folder's top); RPM copies x86_64/ itself, which stays in the published path (RHEL<N>/branches/X.Y/<pipeline>/x86_64/).
    branch_tree() {
        mkdir -p "$1"
        cp -R "$2" "$1/"
        cp "$PUBLIC_DIR/GPG_PUBLIC_KEY" "$work/pipeline.json" "$1/"
        [[ ! -d "$3" ]] || cp -R "$3/." "$1/"
    }
    branch_tree "$work/deb" "$PUBLIC_DIR/debian/." "$work/files/debian"
    python3 "$helper" publish --repository "debian-branches-$dashed" --pipeline "$CI_PIPELINE_ID" \
        --tree "$work/deb" --no-lock --apply --output pulp-branches-deb.json
    echo "Published to $PF_PACKAGE_ORIGIN/downloads/PacketFence/debian/branches/$release/$CI_PIPELINE_ID/"
    for n in "${el_versions[@]}"; do
        [[ -d "$PUBLIC_DIR/centos/$n/x86_64/repodata" ]] || continue
        branch_tree "$work/rpm$n" "$PUBLIC_DIR/centos/$n/x86_64" "$work/files/rhel$n"
        python3 "$helper" publish --repository "rhel$n-branches-$dashed" --pipeline "$CI_PIPELINE_ID" \
            --tree "$work/rpm$n" --no-lock --apply --output "pulp-branches-rpm-el$n.json"
        echo "Published to $PF_PACKAGE_ORIGIN/downloads/PacketFence/RHEL$n/branches/$release/$CI_PIPELINE_ID/"
    done
    exit 0
fi

# release: the native repository serving each OS (Pulp signs its own index); a Debian suite may live in
# another suite's repository (a newer Debian added to the same URL).
for n in "${el_versions[@]}"; do
    if ! native_rpm=$(python3 ci/pulp/native.py rpm "$release" "$n"); then
        # Only devel may run ahead of the packaging side (an unreleased X.Y); a release must reach every OS it built.
        if [[ "${CI_COMMIT_REF_NAME:-}" != devel ]]; then
            echo "No native EL$n repository for $release: create packetfence-$dashed-el$n on the packaging side" >&2
            exit 1
        fi
        echo "No native EL$n repository for $release yet (devel); RHEL$n/$release unchanged"
        continue
    fi
    mapfile -t rpms < <(find "$PUBLIC_DIR/centos/$n/x86_64" -type f -name '*.rpm' ! -name '*.src.rpm' | sort)
    (( ${#rpms[@]} )) || { echo "No .rpm in the generated EL$n tree" >&2; exit 1; }
    python3 ci/pulp/vendor/pulp_publish.py rpm "$native_rpm" "${rpms[@]}" --release "$release" > "pulp-release-rpm-el$n.json"
    echo "Published ${#rpms[@]} packages to $PF_PACKAGE_ORIGIN/downloads/PacketFence/RHEL$n/$release/x86_64 (native)"
done
merge_suites=()
for suite in "${suites[@]}"; do
    if ! native=$(python3 ci/pulp/native.py deb "$release" "$suite"); then
        merge_suites+=("$suite")
        continue
    fi
    # Exactly the packages this suite's index lists (a pool can hold several suites).
    mapfile -t debs < <(find "$PUBLIC_DIR/debian/dists/$suite" -name Packages -path '*/binary-*' -exec sed -n 's/^Filename: //p' {} + \
        | sort -u | sed "s#^#$PUBLIC_DIR/debian/#")
    (( ${#debs[@]} )) || { echo "No .deb listed for $suite in the generated tree" >&2; exit 1; }
    python3 ci/pulp/vendor/pulp_publish.py deb "$native" "${debs[@]}" \
        --codename "$suite" --component "$suite" --release "$release" > "pulp-release-$suite.json"
    echo "Published ${#debs[@]} packages to $PF_PACKAGE_ORIGIN/downloads/PacketFence/debian/$release ($suite, native)"
done
(( ${#merge_suites[@]} )) || exit 0
: "${GPG_KEY_FINGERPRINT:?Set the approved signing fingerprint explicitly}"
for suite in "${merge_suites[@]}"; do
    python3 "$helper" merge-apt --repository "debian-$dashed" --tree "$PUBLIC_DIR/debian" \
        --content-url "$PF_PACKAGE_ORIGIN/downloads/PacketFence/debian/$release" --codename "$suite" \
        --work "$work/deb-$suite" --apply --output "pulp-release-tree-$suite.json"
    echo "Published to $PF_PACKAGE_ORIGIN/downloads/PacketFence/debian/$release ($suite, file tree)"
done
