#!/bin/bash
#
# Check Azure AD device group membership via Microsoft Graph.
#
# Usage:
#   ./check_azuread_device_groups.sh <TENANT_ID> <CLIENT_ID> <CLIENT_SECRET> <DEVICE> [LOOKUP] [--transitive]
#
#   TENANT_ID     - Azure AD tenant ID (GUID) or domain (e.g. contoso.onmicrosoft.com)
#   CLIENT_ID     - App registration client (application) ID
#   CLIENT_SECRET - App registration client secret
#   DEVICE        - Device identifier (see LOOKUP)
#   LOOKUP        - How to interpret DEVICE: object-id (default) | device-id | name
#                     object-id : Azure AD object ID of the device (default)
#                     device-id : Azure AD device ID (the deviceId attribute)
#                     name      : displayName (case-sensitive exact match)
#   --transitive  - Include nested group memberships (uses transitiveMemberOf)
#
# The app registration needs at least Device.Read.All and GroupMember.Read.All
# (Application permissions, admin-consented).
#
# Debug:
#   Set DEBUG=1 to log every HTTP call (URL, status, body) to stderr.
#   Token values are redacted. Example:
#     DEBUG=1 ./check_azuread_device_groups.sh $TID $CID $SECRET <device>
#
# Examples:
#   ./check_azuread_device_groups.sh $TID $CID $SECRET 11111111-2222-3333-4444-555555555555
#   ./check_azuread_device_groups.sh $TID $CID $SECRET LAPTOP-ABC123 name --transitive

set -u

DEBUG="${DEBUG:-0}"

dbg() {
  [ "$DEBUG" = "1" ] || return 0
  printf '[debug] %s\n' "$*" >&2
}

# Curl wrapper that logs URL, HTTP status, and body when DEBUG=1.
# Usage: dbg_curl <label> <curl args...>
# Echoes only the response body to stdout.
dbg_curl() {
  local label="$1"; shift
  if [ "$DEBUG" != "1" ]; then
    curl -sS "$@"
    return $?
  fi
  local tmp status body
  tmp=$(mktemp)
  status=$(curl -sS -o "$tmp" -w '%{http_code}' "$@")
  body=$(cat "$tmp")
  rm -f "$tmp"
  printf '[debug] --- %s ---\n' "$label" >&2
  printf '[debug] curl args: ' >&2
  for a in "$@"; do
    case "$a" in
      *client_secret=*) printf "'client_secret=***REDACTED***' " >&2 ;;
      Authorization:*) printf "'Authorization: Bearer ***REDACTED***' " >&2 ;;
      *) printf "%q " "$a" >&2 ;;
    esac
  done
  printf '\n[debug] http %s\n' "$status" >&2
  if [ -n "$body" ] && echo "$body" | jq . >/dev/null 2>&1; then
    echo "$body" | jq . >&2
  else
    printf '[debug] body: %s\n' "$body" >&2
  fi
  printf '%s' "$body"
}

TENANT_ID="${1:?Usage: $0 <TENANT_ID> <CLIENT_ID> <CLIENT_SECRET> <DEVICE> [LOOKUP] [--transitive]}"
CLIENT_ID="${2:?Missing CLIENT_ID}"
CLIENT_SECRET="${3:?Missing CLIENT_SECRET}"
DEVICE="${4:?Missing DEVICE}"
LOOKUP="${5:-object-id}"
TRANSITIVE_FLAG="${6:-}"

case "$LOOKUP" in
  --transitive)
    TRANSITIVE_FLAG="$LOOKUP"
    LOOKUP="object-id"
    ;;
  object-id|device-id|name) ;;
  *)
    echo "ERROR: invalid LOOKUP '$LOOKUP' (expected: object-id | device-id | name)" >&2
    exit 2
    ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required (install with: yum install jq  or  apt-get install jq)" >&2
  exit 2
fi

GRAPH="https://graph.microsoft.com/v1.0"
LOGIN="https://login.microsoftonline.com"

dbg "tenant=${TENANT_ID} client_id=${CLIENT_ID} device='${DEVICE}' lookup=${LOOKUP} transitive=${TRANSITIVE_FLAG:-no}"

# 1. Get an admin token (client_credentials)
TOKEN_RESP=$(dbg_curl "POST token" -X POST "${LOGIN}/${TENANT_ID}/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode "client_secret=${CLIENT_SECRET}" \
  --data-urlencode "scope=https://graph.microsoft.com/.default" \
  --data-urlencode "grant_type=client_credentials")

TOKEN=$(echo "$TOKEN_RESP" | jq -r '.access_token // empty')
if [ -z "$TOKEN" ]; then
  echo "ERROR: failed to obtain access token." >&2
  echo "$TOKEN_RESP" | jq . >&2 2>/dev/null || echo "$TOKEN_RESP" >&2
  exit 1
fi
dbg "token acquired (len=${#TOKEN}, expires_in=$(echo "$TOKEN_RESP" | jq -r '.expires_in // "?"')s)"

# 2. Resolve the device to its object ID
case "$LOOKUP" in
  object-id)
    OBJECT_ID="$DEVICE"
    ;;
  device-id)
    LOOKUP_RESP=$(dbg_curl "GET devices?\$filter=deviceId" -G "${GRAPH}/devices" \
      -H "Authorization: Bearer ${TOKEN}" \
      --data-urlencode "\$filter=deviceId eq '${DEVICE}'" \
      --data-urlencode "\$select=id,displayName,deviceId")
    OBJECT_ID=$(echo "$LOOKUP_RESP" | jq -r '.value[0].id // empty')
    ;;
  name)
    LOOKUP_RESP=$(dbg_curl "GET devices?\$filter=displayName" -G "${GRAPH}/devices" \
      -H "Authorization: Bearer ${TOKEN}" \
      --data-urlencode "\$filter=displayName eq '${DEVICE}'" \
      --data-urlencode "\$select=id,displayName,deviceId")
    COUNT=$(echo "$LOOKUP_RESP" | jq -r '.value | length')
    if [ "$COUNT" -gt 1 ]; then
      echo "WARN: ${COUNT} devices matched displayName '${DEVICE}'. Showing the first; refine with object-id or device-id." >&2
    fi
    OBJECT_ID=$(echo "$LOOKUP_RESP" | jq -r '.value[0].id // empty')
    ;;
esac
dbg "resolved object_id=${OBJECT_ID:-<none>}"

if [ -z "$OBJECT_ID" ]; then
  echo "ERROR: no device matched '${DEVICE}' (lookup: ${LOOKUP})." >&2
  [ -n "${LOOKUP_RESP:-}" ] && echo "$LOOKUP_RESP" | jq . >&2
  exit 1
fi

# 3. Print device summary
DEVICE_INFO=$(dbg_curl "GET device" "${GRAPH}/devices/${OBJECT_ID}?\$select=id,displayName,deviceId,operatingSystem,operatingSystemVersion,trustType,isCompliant,accountEnabled" \
  -H "Authorization: Bearer ${TOKEN}")

if echo "$DEVICE_INFO" | jq -e '.error' >/dev/null 2>&1; then
  echo "ERROR: failed to read device ${OBJECT_ID}:" >&2
  echo "$DEVICE_INFO" | jq -r '.error.message' >&2
  exit 1
fi

echo "=== Device ==="
echo "$DEVICE_INFO" | jq -r '
  "id              : \(.id)",
  "displayName     : \(.displayName)",
  "deviceId        : \(.deviceId)",
  "operatingSystem : \(.operatingSystem) \(.operatingSystemVersion // "")",
  "trustType       : \(.trustType // "n/a")",
  "isCompliant     : \(.isCompliant // "n/a")",
  "accountEnabled  : \(.accountEnabled)"
'

# 4. Fetch group membership (paginated)
if [ "$TRANSITIVE_FLAG" = "--transitive" ]; then
  ENDPOINT="${GRAPH}/devices/${OBJECT_ID}/transitiveMemberOf/microsoft.graph.group?\$select=id,displayName,securityEnabled,groupTypes&\$top=999"
  LABEL="Groups (transitive)"
else
  ENDPOINT="${GRAPH}/devices/${OBJECT_ID}/memberOf/microsoft.graph.group?\$select=id,displayName,securityEnabled,groupTypes&\$top=999"
  LABEL="Groups (direct)"
fi

echo ""
echo "=== ${LABEL} ==="

NEXT="$ENDPOINT"
TOTAL=0
PAGE_NUM=0
while [ -n "$NEXT" ] && [ "$NEXT" != "null" ]; do
  PAGE_NUM=$((PAGE_NUM + 1))
  PAGE=$(dbg_curl "GET memberOf page ${PAGE_NUM}" "$NEXT" -H "Authorization: Bearer ${TOKEN}")

  if echo "$PAGE" | jq -e '.error' >/dev/null 2>&1; then
    echo "ERROR: graph call failed:" >&2
    echo "$PAGE" | jq -r '.error.message' >&2
    exit 1
  fi

  COUNT=$(echo "$PAGE" | jq -r '.value | length')
  TOTAL=$((TOTAL + COUNT))

  echo "$PAGE" | jq -r '
    .value[]
    | select((."@odata.type" // "#microsoft.graph.group") == "#microsoft.graph.group")
    | "  - \(.displayName // "(no name)")  [id=\(.id), security=\(.securityEnabled), types=\((.groupTypes // []) | join(",") | if . == "" then "Security" else . end)]"
  '

  NEXT=$(echo "$PAGE" | jq -r '."@odata.nextLink" // empty')
done

echo ""
echo "Total memberships: ${TOTAL}"
