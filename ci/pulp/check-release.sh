#!/bin/bash
# Release tag pipelines: stop before any build unless Pulp is ready for this version (check-release.py).
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
: "${PF_PACKAGE_ORIGIN:?}" "${CI_COMMIT_TAG:?}"
PULP_USERNAME=$(bash ci/pulp/psono-field.sh "${PSONO_CI_PULP_PACKAGES_ID:?}" username)
PULP_PASSWORD=$(bash ci/pulp/psono-field.sh "$PSONO_CI_PULP_PACKAGES_ID" password)
export PULP_URL=$PF_PACKAGE_ORIGIN PULP_USERNAME PULP_PASSWORD
os_list=$(sed -n "s/^OS_SUPPORTED='\(.*\)'$/\1/p" ci/lib/common/functions.sh)
exec python3 ci/pulp/check-release.py --tag "$CI_COMMIT_TAG" --os-list "${os_list:?OS_SUPPORTED not found}"
