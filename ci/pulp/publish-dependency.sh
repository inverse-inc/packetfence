#!/bin/bash
# A dependency package built by GitHub Actions (packetfence-perl, fingerbank perl-client) -> the native
# repository of this branch's release (conf/pf-release) on the package origin, next to the PacketFence
# packages that depend on it. A version the repository already holds is left as it is (a rebuild never
# replaces a released package). Usage: publish-dependency.sh debian11|debian12|rhel8 <package files...>
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
image=${1:?debian11, debian12 or rhel8}
shift
(( $# )) || { echo 'No package to publish' >&2; exit 1; }
# A feature branch's build (a [perl] commit) stays out of the release repositories.
branch=${BRANCH_NAME:?the branch the package was built from}
if [[ ! $branch =~ ^(devel|maintenance/[0-9]+\.[0-9]+)$ ]]; then
    echo "Only devel and maintenance/X.Y publish dependency packages: $branch is not published"
    exit 0
fi
case $image in
    debian11) kind=deb target=bullseye os=Debian-11 ;;
    debian12) kind=deb target=bookworm os=Debian-12 ;;
    rhel8) kind=rpm target=8 os=RHEL-8 ;;
    *) echo "Unknown image type $image" >&2; exit 1 ;;
esac
release=$(sed -nE 's/^PacketFence ([0-9]+\.[0-9]+)\.[0-9]+.*$/\1/p' conf/pf-release)
[[ -n $release ]] || { echo 'Cannot determine PacketFence release' >&2; exit 1; }
os_list=$(sed -n "s/^OS_SUPPORTED='\(.*\)'$/\1/p" ci/lib/common/functions.sh)
if [[ " $os_list " != *" $os "* ]]; then
    echo "PacketFence $release does not support $os: the $image packages are not published"
    exit 0
fi
PF_PACKAGE_ORIGIN=${PF_PACKAGE_ORIGIN:-https://packages.packetfence.com}
[[ $PF_PACKAGE_ORIGIN =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?$ ]] || { echo 'PF_PACKAGE_ORIGIN must be an HTTPS origin' >&2; exit 1; }
[[ -n ${PSONO_CI_PULP_PACKAGES_ID:-} ]] || { echo 'PSONO_CI_PULP_PACKAGES_ID is empty: set it in the repository variables' >&2; exit 1; }
python3 -c 'import requests_toolbelt' 2>/dev/null || { echo 'python3-requests-toolbelt is missing from the job image' >&2; exit 1; }
[[ $kind != rpm ]] || python3 -c 'import rpm' 2>/dev/null || { echo 'python3-rpm is missing from the job image' >&2; exit 1; }
PULP_USERNAME=$(bash ci/pulp/psono-field.sh "$PSONO_CI_PULP_PACKAGES_ID" username)
PULP_PASSWORD=$(bash ci/pulp/psono-field.sh "$PSONO_CI_PULP_PACKAGES_ID" password)
export PULP_URL=$PF_PACKAGE_ORIGIN PULP_USERNAME PULP_PASSWORD
status=0
native=$(python3 ci/pulp/native.py "$kind" "$release" "$target") || status=$?
(( status < 2 )) || exit 1
if (( status )); then
    # As publish-packages.sh: only devel may run ahead of the packaging side (an unreleased X.Y).
    if [[ $branch == devel ]]; then
        echo "::warning::No native $os repository for $release yet (devel): the $image packages are not published; re-run this workflow once it exists"
        exit 0
    fi
    echo "No native $os repository for $release on $PF_PACKAGE_ORIGIN: create or grant it on the packaging side" >&2
    exit 1
fi
packages=()
for package in "$@"; do
    status=0
    version=$(python3 ci/pulp/published.py "$kind" "$native" "$package") || status=$?
    case $status in
        0) echo "::warning::$version is already in $native: left as it is (bump the version to publish a change)" ;;
        1) packages+=("$package") ;;
        *) exit 1 ;;
    esac
done
(( ${#packages[@]} )) || { echo "Nothing new to publish to $native"; exit 0; }
if [[ $kind == deb ]]; then
    python3 ci/pulp/vendor/pulp_publish.py deb "$native" "${packages[@]}" --codename "$target" --component "$target" --release "$release"
else
    python3 ci/pulp/vendor/pulp_publish.py rpm "$native" "${packages[@]}" --release "$release"
fi
echo "Published ${#packages[@]} $image package(s) to $native ($release)"
