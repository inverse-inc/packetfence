#!/usr/bin/env bash
# install.sh — finish a pfchatbot deployment on a PacketFence install that
# already has the code (lib/containers/addons pfchatbot dirs) and a
# container image. Idempotent: safe to re-run, including after PF upgrades.
#
#   bash /usr/local/pf/containers/pfchatbot/install.sh [--image TAG]
set -u

PF=/usr/local/pf
IMAGE="pf-chatbot"
while [ $# -gt 0 ]; do case "$1" in
  --image) IMAGE="$2"; shift 2 ;;
  *) echo "unknown arg: $1" >&2; exit 2 ;;
esac; done

B=$(tput bold 2>/dev/null||true); N=$(tput sgr0 2>/dev/null||true)
step(){ echo; echo "${B}==> $*${N}"; }
ok(){ echo "  ok    $*"; }
warn(){ echo "  WARN  $*"; }
die(){ echo "  FAIL  $*" >&2; exit 1; }

step "1. Preflight"
[ -f "$PF/conf/pf-release" ] || die "no PacketFence at $PF"
ok "$(cat $PF/conf/pf-release)"
command -v docker >/dev/null || die "docker not found"
for d in lib/pfchatbot containers/pfchatbot addons/pfchatbot; do
  [ -d "$PF/$d" ] || die "$PF/$d missing — deploy the pfchatbot dirs first"
done
ok "pfchatbot directories present"

# integration layer: live caddy conf + roles + authz map in the binary
grep -q 'pfchatbot' "$PF/conf/caddy-services/api.conf" 2>/dev/null \
  || die "no pfchatbot block in conf/caddy-services/api.conf — on pre-merge installs, mirror it from api.conf.example (see README step 1)"
ok "caddy route present"
grep -q '^\[chatbot-user\]' "$PF/conf/adminroles.conf" "$PF/conf/adminroles.conf.defaults" 2>/dev/null \
  || die "chatbot roles missing — mirror [chatbot-user]/[chatbot-admin] from adminroles.conf.example"
ok "admin roles present"
APIFE=$(docker ps --format '{{.Names}}' | grep -m1 -i 'api-frontend' || true)
if [ -n "$APIFE" ]; then
  if docker exec "$APIFE" sh -c 'strings /usr/local/pf/sbin/pfhttpd 2>/dev/null | grep -qm1 pfchatbot'; then
    ok "api-frontend binary carries the pfchatbot authz map"
  else
    die "running pfhttpd lacks the pfchatbot authz map — rebuild/overlay it (README step 2)"
  fi
else
  warn "api-frontend container not found; skipping authz-map check"
fi

# image
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  ok "image $IMAGE present"
else
  if [ -f "$PF/.dockerignore" ] || cat > "$PF/.dockerignore" <<'DI'
*
!lib/pfchatbot
!containers/pfchatbot
containers/pfchatbot/docs
DI
  then ok ".dockerignore in place"; fi
  step "1b. Image $IMAGE absent — building"
  docker build -t "$IMAGE" -f "$PF/containers/pfchatbot/Dockerfile" "$PF" \
    || die "image build failed"
fi

# required mounts the unit depends on
for f in /var/lib/mysql/mysql.sock "$PF/conf/local_secret" "$PF/docs/api/spec/openapi.json" \
         "$PF/conf/pf.conf" "$PF/conf/pf.conf.defaults" "$PF/conf/pfconfig.conf"; do
  [ -e "$f" ] || die "required path missing: $f"
done
ok "all unit mount sources exist"

step "2. One-time DB grant (store.init() needs DDL; pf@localhost already holds DROP+DML)"
if mysql -S /var/lib/mysql/mysql.sock -e "SHOW GRANTS FOR 'pf'@'localhost'" 2>/dev/null | grep -q 'CREATE.*ON `pf`\.\*'; then
  ok "grant already present"
else
  mysql -S /var/lib/mysql/mysql.sock -e \
    "GRANT CREATE, ALTER, INDEX ON pf.* TO 'pf'@'localhost'; FLUSH PRIVILEGES;" \
    || die "could not grant — run as a user with MySQL root socket access"
  ok "granted CREATE, ALTER, INDEX on pf.* to pf@localhost"
fi

step "3. Environment files"
EX="$PF/lib/pfchatbot/pfchatbot.env.example"
[ -f "$EX" ] || EX="$PF/containers/pfchatbot/pfchatbot.env.example"
if [ ! -f "$PF/conf/pfchatbot.env" ]; then
  cp "$EX" "$PF/conf/pfchatbot.env"
  warn "created conf/pfchatbot.env from the example — EDIT IT: PF_ADMIN_URL"
else
  ok "conf/pfchatbot.env exists"
fi
if [ ! -f "$PF/conf/pfchatbot-testtool.env" ]; then
  EXT="$PF/lib/pfchatbot/pfchatbot-testtool.env.example"
  [ -f "$EXT" ] || EXT="$PF/containers/pfchatbot/pfchatbot-testtool.env.example"
  cp "$EXT" "$PF/conf/pfchatbot-testtool.env"
  ok "created conf/pfchatbot-testtool.env (defaults are portable)"
else
  ok "conf/pfchatbot-testtool.env exists"
fi
chmod 600 "$PF/conf/pfchatbot.env" "$PF/conf/pfchatbot-testtool.env"
if grep -qE 'REPLACE-ME|sk-REPLACE' "$PF/conf/pfchatbot.env"; then
  warn "placeholders remain in conf/pfchatbot.env — the service will start, but"
  warn "the bot ignores them only where pf.conf [pfchatbot] sets the same setting"
fi

step "4. Documentation corpus for RAG"
if ls "$PF/containers/pfchatbot/docs/"*.txt >/dev/null 2>&1; then
  ok "docs already fetched"
else
  DOCS_DIR="$PF/containers/pfchatbot/docs" bash "$PF/lib/pfchatbot/fetch_docs.sh" \
    || warn "doc fetch failed (offline?) — the bot still works; RAG indexes the API spec only"
fi

step "5. Service"
UNIT=packetfence-chatbot
install -m 0644 "$PF/containers/pfchatbot/$UNIT.service" "/etc/systemd/system/$UNIT.service"
systemctl daemon-reload
systemctl enable "$UNIT" >/dev/null 2>&1 || true
systemctl restart "$UNIT"
sleep 8
systemctl is-active --quiet "$UNIT" || { journalctl -u "$UNIT" -n 25 --no-pager; die "service did not start"; }
ok "service active"
BIND=$(journalctl -u "$UNIT" -n 50 --no-pager 2>/dev/null | grep -oE 'binding [0-9.]+:[0-9]+' | tail -1 | awk '{print $2}')
ok "bound ${BIND:-unknown}"

step "6. Settings (pf.conf [pfchatbot])"
# provider/key/model and the PF API account live in pf.conf, edited from
# Configuration > Integration > NACBot; pfchatbot.env is the fallback
for k in provider api_key pf_username pf_password; do
  if sed -n '/^\[pfchatbot\]/,/^\[/p' "$PF/conf/pf.conf" 2>/dev/null | grep -qE "^$k *= *[^ ]"; then
    ok "$k set in pf.conf"
  else
    warn "$k not set in pf.conf [pfchatbot] — set it in Configuration > Integration > NACBot (or pfchatbot.env)"
  fi
done

step "7. Self-tests"
PASS=0; FAIL=0; SKIP=0
t_ok(){ PASS=$((PASS+1)); echo "  pass  $*"; }
t_fail(){ FAIL=$((FAIL+1)); echo "  FAIL  $*" >&2; }
t_skip(){ SKIP=$((SKIP+1)); echo "  skip  $*"; }

HOST="${BIND%%:*}"; PORT="${BIND##*:}"
[ -n "$HOST" ] || { HOST=""; t_fail "could not determine bind address from the journal"; }

# 7.0 wait out first-boot indexing (model download + RAG embed can take minutes)
if [ -n "$HOST" ]; then
  echo "  ...   waiting for startup complete (up to 600s; first boot embeds the RAG index)"
  i=0
  until journalctl -u "$UNIT" --since '15 min ago' --no-pager 2>/dev/null | grep -q 'startup complete'; do
    i=$((i+10)); [ $i -ge 600 ] && break
    systemctl is-active --quiet "$UNIT" || break
    sleep 10
  done
  if journalctl -u "$UNIT" --since '15 min ago' --no-pager 2>/dev/null | grep -q 'startup complete'; then
    t_ok "startup complete"
  else
    t_fail "no 'startup complete' within 600s — journalctl -u $UNIT -f"
  fi
fi

# 7.1 API serves (the UI is part of the admin SPA, not this service)
if [ -n "$HOST" ] && curl -s -m 10 "http://$HOST:$PORT/config" | grep -q '"pf_version"'; then
  t_ok "API serves at $HOST:$PORT"
else
  [ -n "$HOST" ] && t_fail "API not serving at $HOST:$PORT"
fi

# 7.2 conversation store (via journal — /chat transitively proves it too)
if journalctl -u "$UNIT" --since '15 min ago' --no-pager 2>/dev/null | grep -q 'conversation store ready'; then
  t_ok "conversation store ready"
else
  t_fail "store not ready — check DB grant / credentials (journalctl -u $UNIT | grep store)"
fi

# 7.3 provider configured? (informational — key may legitimately come later via the UI)
if journalctl -u "$UNIT" --since '15 min ago' --no-pager 2>/dev/null | grep -q 'provider='; then
  t_ok "LLM provider initialized"
else
  t_skip "no provider yet — set it in Configuration > Integration > NACBot (applies without restart)"
fi

# 7.4 chat round-trip (only meaningful with a provider)
if [ -n "$HOST" ]; then
  R=$(curl -s -m 60 -X POST "http://$HOST:$PORT/chat" -H 'Content-Type: application/json'       -d '{"message":"ping"}' | sed -n 's/.*"reply"[": ]*"\([^"]*\).*/\1/p' | head -c 60)
  case "$R" in
    "") t_fail "/chat returned no reply (journalctl -u $UNIT -n 40)" ;;
    *"starting up"*|*"No provider"*) t_skip "/chat: $R" ;;
    *) t_ok "/chat answers: $R" ;;
  esac
fi

# 7.5 test-tool helper socket
if [ -n "$HOST" ] && curl -s -m 10 "http://$HOST:$PORT/testtools" | grep -q '"enabled": *true'; then
  t_ok "test-tool helper reachable"
else
  t_skip "test-tool helper not enabled (socket missing?) — Run test will be unavailable"
fi

# 7.6 not exposed beyond the bind address (probe every OTHER global IPv4)
EXPOSED=""
for ip in $(ip -4 -o addr show scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]}'); do
  [ "$ip" = "$HOST" ] && continue
  curl -s -m 3 "http://$ip:$PORT/" >/dev/null 2>&1 && EXPOSED="$EXPOSED $ip"
done
if [ -n "$EXPOSED" ]; then
  t_fail "port $PORT ALSO answers on:$EXPOSED — set BIND_HOST explicitly and restart"
else
  t_ok "port $PORT answers only on $HOST"
fi

# 7.7 proxied path: routing + authz gates (unauthenticated — 401 IS the pass:
#     it proves haproxy->caddy routed the path and the AAA layer gated it)
ADMIN_HOST=$(sed -n 's/^PF_ADMIN_URL=https*:\/\/\([^:/]*\).*/\1/p' "$PF/conf/pfchatbot.env" 2>/dev/null | head -1)
ADMIN_HOST="${ADMIN_HOST:-127.0.0.1}"
CODE=$(curl -sk -m 10 -o /dev/null -w '%{http_code}' "https://$ADMIN_HOST:1443/api/v1/pfchatbot/config" 2>/dev/null)
case "$CODE" in
  401) t_ok "proxy path routed and auth-gated (401 unauthenticated, as designed)" ;;
  200) t_fail "proxy answered 200 WITHOUT a token — AAA is not gating /api/v1/pfchatbot" ;;
  404) t_fail "proxy 404 — caddy block missing or PF_SERVICES_URL_PFCHATBOT not set in the api-frontend env" ;;
  502|503) t_fail "proxy routed but cannot reach the bot — bind ($HOST:$PORT) vs services_url mismatch" ;;
  000|"") t_skip "could not reach https://$ADMIN_HOST:1443 from here" ;;
  *) t_fail "proxy returned unexpected HTTP $CODE" ;;
esac

echo
echo "${B}Self-tests: $PASS passed, $FAIL failed, $SKIP skipped.${N}"
[ "$FAIL" = 0 ] || echo "  Fix the failures above, then re-run this script (idempotent)."
echo
echo "Authenticated acceptance (needs an admin token; see README for the full matrix):"
echo "  TOK=\$(curl -sk https://$ADMIN_HOST:1443/api/v1/login -d '{\"username\":\"admin\",\"password\":\"...\"}' | jq -r .token)"
echo "  curl -sk -H \"Authorization: \$TOK\" https://$ADMIN_HOST:1443/api/v1/pfchatbot/config | jq ."
echo "  curl -sk -X POST -H \"Authorization: \$TOK\" -H 'Content-Type: application/json' \\"
echo "    https://$ADMIN_HOST:1443/api/v1/pfchatbot/chat -d '{\"message\":\"ping\"}' | jq -r .reply"
echo
echo "${B}Done.${N} Remaining manual items:"
echo "  - set the provider, API key and PF API account in Configuration > Integration > NACBot"
echo "  - open the assistant from the admin UI navbar (needs the CHATBOT_READ admin role)"
echo "  - acceptance matrix: chatbot-user read=200/write=403, chatbot-admin 200/200 (see README)"
echo "  - after any PF upgrade: re-run this script (it is idempotent) — see addons/pfchatbot/MODIFICATIONS.md"
