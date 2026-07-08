#!/bin/bash
#
# Create 1100 roles via the PacketFence API
#
# Usage: ./create_1100_roles.sh <PF_HOST> [USERNAME] [PASSWORD]
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

echo "Authenticated successfully. Creating 1100 roles..."

SUCCESS=0
FAIL=0

for i in $(seq 1 1100); do
  ROLE_NAME="test_role_$(printf '%04d' $i)"

  HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" -X POST "$BASE_URL" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"${ROLE_NAME}\",\"notes\":\"Test role ${i} created by script\",\"max_nodes_per_pid\":0}")

  if [ "$HTTP_CODE" -eq 201 ]; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  FAILED to create ${ROLE_NAME} (HTTP ${HTTP_CODE})"
  fi

  # Progress every 50 roles
  if [ $((i % 50)) -eq 0 ]; then
    echo "  Progress: ${i}/1100 roles processed..."
  fi
done

echo ""
echo "Done. Created: ${SUCCESS}, Failed: ${FAIL}"
