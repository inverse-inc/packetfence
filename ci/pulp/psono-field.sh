#!/bin/bash
# Print the username or the password of a Psono entry (application or website password), for the
# Pulp CI accounts. Usage: psono-field.sh <secret id> username|password. Never trace the output.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
: "${PSONO_CI_API_KEY_ID:?}" "${PSONO_CI_API_SECRET_KEY_HEX:?}"
field=${2:?username or password}
[[ $field == username || $field == password ]] || exit 2
python3 "$ROOT/addons/packetfence-perl/psono.py" --api_key_id="$PSONO_CI_API_KEY_ID" \
    --api_key_secret_key="$PSONO_CI_API_SECRET_KEY_HEX" --secret_id="${1:?Psono secret id}" --return_value=all \
| python3 -c 'import json, sys
field, entry = sys.argv[1], json.load(sys.stdin)
value = next((entry[k] for k in ("website_password_" + field, "application_password_" + field, field) if entry.get(k)), "")
if not value:
    sys.exit("The Psono entry has no " + field)
sys.stdout.write(value)' "$field"
