#!/bin/bash
# Print the password of a Psono entry (application or website password), for the Pulp CI accounts.
# Usage: psono-password.sh <secret id>. Never trace the output.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
: "${PSONO_CI_API_KEY_ID:?}" "${PSONO_CI_API_SECRET_KEY_HEX:?}"
python3 "$ROOT/addons/packetfence-perl/psono.py" --api_key_id="$PSONO_CI_API_KEY_ID" \
    --api_key_secret_key="$PSONO_CI_API_SECRET_KEY_HEX" --secret_id="${1:?Psono secret id}" --return_value=all \
| python3 -c 'import json, sys
entry = json.load(sys.stdin)
value = next((entry[k] for k in ("website_password_password", "application_password_password", "password") if entry.get(k)), "")
if not value:
    sys.exit("The Psono entry has no password")
sys.stdout.write(value)'
