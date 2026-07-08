#!/bin/bash
#
# Check that the 1100 roles created by create_1100_roles.sh exist in PacketFence
#
# Usage: ./check_1100_roles.sh <PF_HOST> [USERNAME] [PASSWORD]
#   PF_HOST  - PacketFence server hostname or IP (e.g. 192.168.1.10)
#   USERNAME - API admin username (default: admin)
#   PASSWORD - API admin password (default: admin)

PF_HOST="${1:?Usage: $0 <PF_HOST> [USERNAME] [PASSWORD]}"
USERNAME="${2:-admin}"
PASSWORD="${3:-admin}"

BASE_URL="https://${PF_HOST}:9999/api/v1/config/roles"

# Get an API token
TOKEN=$(curl -sk -X POST "https://${PF_HOST}:9999/api/v1/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to obtain API token. Check host, username, and password."
  exit 1
fi

echo "Authenticated successfully. Fetching all roles..."

# Fetch all roles from the API
ALL_ROLES=$(curl -sk -X GET "${BASE_URL}?limit=2000" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json")

if [ -z "$ALL_ROLES" ]; then
  echo "ERROR: Failed to fetch roles from API."
  exit 1
fi

FOUND=0
MISSING=0
MISSING_LIST=""

for i in $(seq 1 1100); do
  ROLE_NAME="test_role_$(printf '%04d' $i)"

  if echo "$ALL_ROLES" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('items', data) if isinstance(data, dict) else data
names = [r.get('id', r.get('name', '')) for r in items]
sys.exit(0 if '${ROLE_NAME}' in names else 1)
" 2>/dev/null; then
    FOUND=$((FOUND + 1))
  else
    MISSING=$((MISSING + 1))
    MISSING_LIST="${MISSING_LIST} ${ROLE_NAME}"
  fi

  # Progress every 100 roles
  if [ $((i % 100)) -eq 0 ]; then
    echo "  Progress: ${i}/1100 roles checked..."
  fi
done

echo ""
echo "=== Results ==="
echo "Found:   ${FOUND}/1100"
echo "Missing: ${MISSING}/1100"

if [ "$MISSING" -gt 0 ]; then
  echo ""
  echo "Missing roles:"
  for r in $MISSING_LIST; do
    echo "  - $r"
  done
  exit 1
else
  echo ""
  echo "All 1100 test roles are present."
  exit 0
fi
