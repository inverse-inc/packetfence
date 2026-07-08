#!/bin/bash
#
# Check Azure AD user group membership via Microsoft Graph.
#
# Usage:
#   ./check_azuread_user_groups.sh <TENANT_ID> <CLIENT_ID> <CLIENT_SECRET> <USER> [LOOKUP] [--transitive]
#
#   TENANT_ID     - Azure AD tenant ID (GUID) or domain (e.g. contoso.onmicrosoft.com)
#   CLIENT_ID     - App registration client (application) ID
#   CLIENT_SECRET - App registration client secret
#   USER          - User identifier (see LOOKUP)
#   LOOKUP        - How to interpret USER: upn (default) | object-id | mail | name
#                     upn       : userPrincipalName (e.g. alice@contoso.com) -- default
#                     object-id : Azure AD object ID of the user
#                     mail      : primary mail address (case-insensitive exact match)
#                     name      : displayName (case-sensitive exact match)
#   --transitive  - Include nested group memberships (uses transitiveMemberOf)
#
# The app registration needs at least User.Read.All and GroupMember.Read.All
# (Application permissions, admin-consented).
#
# IMPORTANT: GroupMember.Read.All lets you list a user's memberships but Graph
# may return only the group id with displayName/securityEnabled set to null.
# To get readable group properties (name, type, securityEnabled) you must also
# grant Group.Read.All (or Directory.Read.All) Application permission and
# admin-consent it. This script will fall back to GET /groups/{id} for each
# group whose displayName is null and report a per-group error if that also
# fails, which is the unambiguous signal that group-read consent is missing.
#
# Debug:
#   Set DEBUG=1 to log every HTTP call (URL, status, body) to stderr.
#   Token values are redacted. Example:
#     DEBUG=1 ./check_azuread_user_groups.sh $TID $CID $SECRET alice@contoso.com
#
# Examples:
#   ./check_azuread_user_groups.sh $TID $CID $SECRET alice@contoso.com
#   ./check_azuread_user_groups.sh $TID $CID $SECRET 11111111-2222-3333-4444-555555555555 object-id
#   ./check_azuread_user_groups.sh $TID $CID $SECRET "Alice Example" name --transitive

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

TENANT_ID="${1:?Usage: $0 <TENANT_ID> <CLIENT_ID> <CLIENT_SECRET> <USER> [LOOKUP] [--transitive]}"
CLIENT_ID="${2:?Missing CLIENT_ID}"
CLIENT_SECRET="${3:?Missing CLIENT_SECRET}"
USER_ARG="${4:?Missing USER}"
LOOKUP="${5:-upn}"
TRANSITIVE_FLAG="${6:-}"

case "$LOOKUP" in
  --transitive)
    TRANSITIVE_FLAG="$LOOKUP"
    LOOKUP="upn"
    ;;
  upn|object-id|mail|name) ;;
  *)
    echo "ERROR: invalid LOOKUP '$LOOKUP' (expected: upn | object-id | mail | name)" >&2
    exit 2
    ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required (install with: yum install jq  or  apt-get install jq)" >&2
  exit 2
fi

GRAPH="https://graph.microsoft.com/v1.0"
LOGIN="https://login.microsoftonline.com"

dbg "tenant=${TENANT_ID} client_id=${CLIENT_ID} user='${USER_ARG}' lookup=${LOOKUP} transitive=${TRANSITIVE_FLAG:-no}"

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

# 2. Resolve the user to its object ID (Graph also accepts UPN directly,
# but resolving up front gives a clearer error and works for mail/name lookups).
case "$LOOKUP" in
  upn|object-id)
    # Both UPN and object-id can be passed straight to /users/{key}
    USER_KEY="$USER_ARG"
    LOOKUP_RESP=$(dbg_curl "GET user (${LOOKUP})" \
      "${GRAPH}/users/${USER_KEY}?\$select=id,displayName,userPrincipalName,mail" \
      -H "Authorization: Bearer ${TOKEN}")
    if echo "$LOOKUP_RESP" | jq -e '.error' >/dev/null 2>&1; then
      echo "ERROR: no user matched '${USER_ARG}' (lookup: ${LOOKUP})." >&2
      echo "$LOOKUP_RESP" | jq -r '.error.message' >&2
      exit 1
    fi
    OBJECT_ID=$(echo "$LOOKUP_RESP" | jq -r '.id // empty')
    ;;
  mail)
    LOOKUP_RESP=$(dbg_curl "GET users?\$filter=mail" -G "${GRAPH}/users" \
      -H "Authorization: Bearer ${TOKEN}" \
      --data-urlencode "\$filter=mail eq '${USER_ARG}'" \
      --data-urlencode "\$select=id,displayName,userPrincipalName,mail")
    COUNT=$(echo "$LOOKUP_RESP" | jq -r '.value | length')
    if [ "$COUNT" -gt 1 ]; then
      echo "WARN: ${COUNT} users matched mail '${USER_ARG}'. Showing the first; refine with upn or object-id." >&2
    fi
    OBJECT_ID=$(echo "$LOOKUP_RESP" | jq -r '.value[0].id // empty')
    ;;
  name)
    LOOKUP_RESP=$(dbg_curl "GET users?\$filter=displayName" -G "${GRAPH}/users" \
      -H "Authorization: Bearer ${TOKEN}" \
      --data-urlencode "\$filter=displayName eq '${USER_ARG}'" \
      --data-urlencode "\$select=id,displayName,userPrincipalName,mail")
    COUNT=$(echo "$LOOKUP_RESP" | jq -r '.value | length')
    if [ "$COUNT" -gt 1 ]; then
      echo "WARN: ${COUNT} users matched displayName '${USER_ARG}'. Showing the first; refine with upn or object-id." >&2
    fi
    OBJECT_ID=$(echo "$LOOKUP_RESP" | jq -r '.value[0].id // empty')
    ;;
esac

if [ -z "$OBJECT_ID" ]; then
  echo "ERROR: no user matched '${USER_ARG}' (lookup: ${LOOKUP})." >&2
  [ -n "${LOOKUP_RESP:-}" ] && echo "$LOOKUP_RESP" | jq . >&2
  exit 1
fi
dbg "resolved object_id=${OBJECT_ID}"

# 3. Print user summary
USER_INFO=$(dbg_curl "GET user" "${GRAPH}/users/${OBJECT_ID}?\$select=id,displayName,userPrincipalName,mail,jobTitle,department,accountEnabled,onPremisesSyncEnabled" \
  -H "Authorization: Bearer ${TOKEN}")

if echo "$USER_INFO" | jq -e '.error' >/dev/null 2>&1; then
  echo "ERROR: failed to read user ${OBJECT_ID}:" >&2
  echo "$USER_INFO" | jq -r '.error.message' >&2
  exit 1
fi

echo "=== User ==="
echo "$USER_INFO" | jq -r '
  "id                    : \(.id)",
  "displayName           : \(.displayName)",
  "userPrincipalName     : \(.userPrincipalName)",
  "mail                  : \(.mail // "n/a")",
  "jobTitle              : \(.jobTitle // "n/a")",
  "department            : \(.department // "n/a")",
  "accountEnabled        : \(.accountEnabled)",
  "onPremisesSyncEnabled : \(.onPremisesSyncEnabled // false)"
'

# 4. Fetch group membership (paginated)
if [ "$TRANSITIVE_FLAG" = "--transitive" ]; then
  ENDPOINT="${GRAPH}/users/${OBJECT_ID}/transitiveMemberOf/microsoft.graph.group?\$select=id,displayName,securityEnabled,groupTypes&\$top=999"
  LABEL="Groups (transitive)"
else
  ENDPOINT="${GRAPH}/users/${OBJECT_ID}/memberOf/microsoft.graph.group?\$select=id,displayName,securityEnabled,groupTypes&\$top=999"
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

  # Iterate per-id so we can fall back to a direct /groups/{id} fetch when
  # displayName comes back null (typical when the app has GroupMember.Read.All
  # but not Group.Read.All / Directory.Read.All, so memberOf returns the ref
  # but the projected properties are stripped).
  while IFS=$'\t' read -r GID GNAME GSEC GTYPES; do
    [ -z "$GID" ] && continue
    if [ "$GNAME" = "null" ] || [ -z "$GNAME" ]; then
      DETAIL=$(dbg_curl "GET group ${GID} (fallback)" \
        "${GRAPH}/groups/${GID}?\$select=id,displayName,securityEnabled,groupTypes" \
        -H "Authorization: Bearer ${TOKEN}")
      if echo "$DETAIL" | jq -e '.error' >/dev/null 2>&1; then
        ERR=$(echo "$DETAIL" | jq -r '.error.code + ": " + .error.message')
        echo "  - (unreadable)  [id=${GID}, error=${ERR}]"
        continue
      fi
      GNAME=$(echo "$DETAIL" | jq -r '.displayName // "(no name)"')
      GSEC=$(echo "$DETAIL"  | jq -r '.securityEnabled')
      GTYPES=$(echo "$DETAIL" | jq -r '(.groupTypes // []) | join(",")')
    fi
    [ -z "$GTYPES" ] && GTYPES="Security"
    echo "  - ${GNAME}  [id=${GID}, security=${GSEC}, types=${GTYPES}]"
  done < <(echo "$PAGE" | jq -r '
    .value[]
    | select((."@odata.type" // "#microsoft.graph.group") == "#microsoft.graph.group")
    | [.id, (.displayName // ""), (.securityEnabled|tostring), ((.groupTypes // []) | join(","))]
    | @tsv
  ')

  NEXT=$(echo "$PAGE" | jq -r '."@odata.nextLink" // empty')
done

echo ""
echo "Total memberships: ${TOTAL}"
