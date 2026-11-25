#!/bin/bash
# A dependency package built by GitHub Actions (packetfence-perl, fingerbank perl-client) -> the native
# repository of this branch's release (conf/pf-release) on the package origin, next to the PacketFence
# packages that depend on it. Usage: publish-dependency.sh debian11|debian12|rhel8 <package files...>
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
release=$(grep -oE '[0-9]+\.[0-9]+' conf/pf-release | head -n1)
os_list=$(sed -n "s/^OS_SUPPORTED='\(.*\)'$/\1/p" ci/lib/common/functions.sh)
if [[ " $os_list " != *" $os "* ]]; then
    echo "PacketFence $release does not support $os: the $image packages are not published"
    exit 0
fi
PF_PACKAGE_ORIGIN=${PF_PACKAGE_ORIGIN:-https://packages.packetfence.com}
[[ $PF_PACKAGE_ORIGIN =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?$ ]] || { echo 'PF_PACKAGE_ORIGIN must be an HTTPS origin' >&2; exit 1; }
[[ -n ${PSONO_CI_PULP_PACKAGES_ID:-} ]] || { echo 'PSONO_CI_PULP_PACKAGES_ID is empty: set it in the repository variables' >&2; exit 1; }
PULP_USERNAME=$(bash ci/pulp/psono-field.sh "$PSONO_CI_PULP_PACKAGES_ID" username)
PULP_PASSWORD=$(bash ci/pulp/psono-field.sh "$PSONO_CI_PULP_PACKAGES_ID" password)
export PULP_URL=$PF_PACKAGE_ORIGIN PULP_USERNAME PULP_PASSWORD
status=0
native=$(python3 ci/pulp/native.py "$kind" "$release" "$target") || status=$?
(( status == 0 )) || { echo "No native $os repository for $release on $PF_PACKAGE_ORIGIN (native.py: $status)" >&2; exit 1; }
if [[ $kind == deb ]]; then
    python3 ci/pulp/vendor/pulp_publish.py deb "$native" "$@" --codename "$target" --component "$target" --release "$release"
else
    python3 ci/pulp/vendor/pulp_publish.py rpm "$native" "$@" --release "$release"
fi
echo "Published $# $image package(s) to $native ($release)"
