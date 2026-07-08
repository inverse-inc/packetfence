#!/bin/bash
#
# Authenticate an Azure AD user (validate username + password) via the
# OAuth2 Resource Owner Password Credentials (ROPC) grant against Microsoft
# Entra ID / Azure AD, then print the resulting identity.
#
# Usage:
#   ./check_azuread_user_auth.sh <TENANT_ID> <CLIENT_ID> <CLIENT_SECRET> <USERNAME> [PASSWORD] [--groups] [--transitive]
#
#   TENANT_ID     - Azure AD tenant ID (GUID) or domain (e.g. contoso.onmicrosoft.com)
#   CLIENT_ID     - App registration client (application) ID
#   CLIENT_SECRET - App registration client secret (use "" / '' for a public client)
#   USERNAME      - User principal name to authenticate (e.g. alice@contoso.com)
#   PASSWORD      - The user's password. If omitted, you are prompted (no echo).
#                   You may also set it via the AAD_PASSWORD environment variable.
#   --groups      - After a successful auth, list the user's group memberships
#                   (read from the user's own token; needs delegated
#                   User.Read + GroupMember.Read.All / Directory.Read.All).
#   --transitive  - Include nested group memberships (uses transitiveMemberOf).
#                   Implies --groups.
#
# ROPC requirements (these mirror what PacketFence's Azure AD auth source does):
#   - The app registration must be enabled for public client / ROPC flows
#     ("Allow public client flows" = Yes in Authentication settings) OR be a
#     confidential client with a secret (then pass CLIENT_SECRET).
#   - The user must NOT require MFA and must not be a guest/federated/social
#     account -- ROPC does not support interactive challenges. A user that is
#     valid but blocked by Conditional Access/MFA returns AADSTS50076/50079,
#     which this script reports distinctly from a wrong password (AADSTS50126).
#   - Delegated scope User.Read is requested so we can read /me on success.
#
# Debug:
#   Set DEBUG=1 to log every HTTP call (URL, status, body) to stderr.
#   Token and password values are redacted. Example:
#     DEBUG=1 ./check_azuread_user_auth.sh $TID $CID $SECRET alice@contoso.com
#
# Examples:
#   ./check_azuread_user_auth.sh $TID $CID $SECRET alice@contoso.com
#   ./check_azuread_user_auth.sh $TID $CID '' alice@contoso.com 'p@ssw0rd' --groups
#   ./check_azuread_user_auth.sh $TID $CID $SECRET alice@contoso.com 'p@ssw0rd' --transitive
#   AAD_PASSWORD='p@ssw0rd' ./check_azuread_user_auth.sh $TID $CID $SECRET alice@contoso.com

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
      *password=*)      printf "'password=***REDACTED***' " >&2 ;;
      Authorization:*)  printf "'Authorization: Bearer ***REDACTED***' " >&2 ;;
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

TENANT_ID="${1:?Usage: $0 <TENANT_ID> <CLIENT_ID> <CLIENT_SECRET> <USERNAME> [PASSWORD] [--groups]}"
CLIENT_ID="${2:?Missing CLIENT_ID}"
CLIENT_SECRET="${3?Missing CLIENT_SECRET (use \"\" for a public client)}"
USERNAME="${4:?Missing USERNAME}"
PASSWORD="${5:-${AAD_PASSWORD:-}}"
FLAG1="${6:-}"
FLAG2="${7:-}"

# Allow a flag to be passed in the PASSWORD position when the password is
# supplied interactively or via AAD_PASSWORD.
case "$PASSWORD" in
  --groups|--transitive)
    FLAG2="$FLAG1"
    FLAG1="$PASSWORD"
    PASSWORD="${AAD_PASSWORD:-}"
    ;;
esac

# Parse the (up to two) trailing flags. --transitive implies --groups.
LIST_GROUPS=0
TRANSITIVE=0
for f in "$FLAG1" "$FLAG2"; do
  case "$f" in
    "") ;;
    --groups) LIST_GROUPS=1 ;;
    --transitive) LIST_GROUPS=1; TRANSITIVE=1 ;;
    *)
      echo "ERROR: invalid flag '$f' (expected: --groups | --transitive)" >&2
      exit 2
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required (install with: yum install jq  or  apt-get install jq)" >&2
  exit 2
fi

# Prompt for the password if it was not provided on the CLI or via env.
if [ -z "$PASSWORD" ]; then
  read -r -s -p "Password for ${USERNAME}: " PASSWORD
  echo "" >&2
fi
if [ -z "$PASSWORD" ]; then
  echo "ERROR: no password supplied." >&2
  exit 2
fi

GRAPH="https://graph.microsoft.com/v1.0"
LOGIN="https://login.microsoftonline.com"

dbg "tenant=${TENANT_ID} client_id=${CLIENT_ID} username='${USERNAME}' groups=${LIST_GROUPS} transitive=${TRANSITIVE} confidential=$([ -n "$CLIENT_SECRET" ] && echo yes || echo no)"

# 1. Authenticate the user with the ROPC (password) grant.
#    scope=openid profile User.Read .default-style scopes give us /me access.
TOKEN_ARGS=(
  -X POST "${LOGIN}/${TENANT_ID}/oauth2/v2.0/token"
  -H "Content-Type: application/x-www-form-urlencoded"
  --data-urlencode "client_id=${CLIENT_ID}"
  --data-urlencode "scope=openid profile https://graph.microsoft.com/User.Read"
  --data-urlencode "username=${USERNAME}"
  --data-urlencode "password=${PASSWORD}"
  --data-urlencode "grant_type=password"
)
# Confidential clients must also send the secret; public clients omit it.
if [ -n "$CLIENT_SECRET" ]; then
  TOKEN_ARGS+=( --data-urlencode "client_secret=${CLIENT_SECRET}" )
fi

TOKEN_RESP=$(dbg_curl "POST token (ROPC)" "${TOKEN_ARGS[@]}")

TOKEN=$(echo "$TOKEN_RESP" | jq -r '.access_token // empty')

if [ -z "$TOKEN" ]; then
  ERR_CODE=$(echo "$TOKEN_RESP" | jq -r '.error // "unknown_error"')
  ERR_DESC=$(echo "$TOKEN_RESP" | jq -r '.error_description // ""')
  # First AADSTS code in the description is the most specific reason.
  AADSTS=$(printf '%s' "$ERR_DESC" | grep -oE 'AADSTS[0-9]+' | head -n1)

  echo "=== Authentication: FAILED ==="
  echo "user  : ${USERNAME}"
  echo "error : ${ERR_CODE}"
  [ -n "$AADSTS" ] && echo "code  : ${AADSTS}"

  case "$AADSTS" in
    AADSTS50126) echo "reason: invalid username or password" ;;
    AADSTS50034) echo "reason: user does not exist in this tenant" ;;
    AADSTS50053) echo "reason: account locked out (too many failed attempts)" ;;
    AADSTS50055) echo "reason: password expired" ;;
    AADSTS50057) echo "reason: account disabled" ;;
    AADSTS50076|AADSTS50079) echo "reason: MFA required -- ROPC cannot satisfy MFA (credentials may still be valid)" ;;
    AADSTS50059) echo "reason: tenant could not be identified from the username" ;;
    AADSTS65001) echo "reason: user/admin has not consented to the requested scopes" ;;
    AADSTS7000218) echo "reason: client requires a secret/credential (public-client flows not enabled?)" ;;
    AADSTS700016) echo "reason: application/client_id not found in this tenant" ;;
    *) [ -n "$ERR_DESC" ] && echo "detail: $(printf '%s' "$ERR_DESC" | head -n1)" ;;
  esac
  exit 1
fi

dbg "token acquired (len=${#TOKEN}, expires_in=$(echo "$TOKEN_RESP" | jq -r '.expires_in // "?"')s)"

echo "=== Authentication: SUCCESS ==="
echo "user        : ${USERNAME}"
echo "token_type  : $(echo "$TOKEN_RESP" | jq -r '.token_type // "?"')"
echo "expires_in  : $(echo "$TOKEN_RESP" | jq -r '.expires_in // "?"')s"
echo "scope       : $(echo "$TOKEN_RESP" | jq -r '.scope // "?"')"

# 2. Read the authenticated identity from /me using the user's own token.
ME=$(dbg_curl "GET /me" \
  "${GRAPH}/me?\$select=id,displayName,userPrincipalName,mail,jobTitle,department,accountEnabled" \
  -H "Authorization: Bearer ${TOKEN}")

if echo "$ME" | jq -e '.error' >/dev/null 2>&1; then
  echo ""
  echo "WARN: authenticated but failed to read /me:" >&2
  echo "$ME" | jq -r '.error.message' >&2
else
  echo ""
  echo "=== Identity (/me) ==="
  echo "$ME" | jq -r '
    "id                : \(.id)",
    "displayName       : \(.displayName)",
    "userPrincipalName : \(.userPrincipalName)",
    "mail              : \(.mail // "n/a")",
    "jobTitle          : \(.jobTitle // "n/a")",
    "department        : \(.department // "n/a")",
    "accountEnabled    : \(.accountEnabled)"
  '
fi

# 3. Optionally list the user's group memberships from their own token.
if [ "$LIST_GROUPS" = "1" ]; then
  echo ""
  if [ "$TRANSITIVE" = "1" ]; then
    echo "=== Groups (transitive) ==="
    NEXT="${GRAPH}/me/transitiveMemberOf/microsoft.graph.group?\$select=id,displayName,securityEnabled,groupTypes&\$top=999"
  else
    echo "=== Groups (direct) ==="
    NEXT="${GRAPH}/me/memberOf/microsoft.graph.group?\$select=id,displayName,securityEnabled,groupTypes&\$top=999"
  fi

  TOTAL=0
  PAGE_NUM=0
  while [ -n "$NEXT" ] && [ "$NEXT" != "null" ]; do
    PAGE_NUM=$((PAGE_NUM + 1))
    PAGE=$(dbg_curl "GET /me/memberOf page ${PAGE_NUM}" "$NEXT" -H "Authorization: Bearer ${TOKEN}")

    if echo "$PAGE" | jq -e '.error' >/dev/null 2>&1; then
      echo "ERROR: graph call failed:" >&2
      echo "$PAGE" | jq -r '.error.message' >&2
      break
    fi

    COUNT=$(echo "$PAGE" | jq -r '.value | length')
    TOTAL=$((TOTAL + COUNT))

    while IFS=$'\t' read -r GID GNAME GSEC GTYPES; do
      [ -z "$GID" ] && continue
      [ -z "$GTYPES" ] && GTYPES="Security"
      echo "  - ${GNAME}  [id=${GID}, security=${GSEC}, types=${GTYPES}]"
    done < <(echo "$PAGE" | jq -r '
      .value[]
      | select((."@odata.type" // "#microsoft.graph.group") == "#microsoft.graph.group")
      | [.id, (.displayName // "(no name)"), (.securityEnabled|tostring), ((.groupTypes // []) | join(","))]
      | @tsv
    ')

    NEXT=$(echo "$PAGE" | jq -r '."@odata.nextLink" // empty')
  done

  echo ""
  echo "Total memberships: ${TOTAL}"
fi
