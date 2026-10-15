#!/usr/bin/env bash
# install.sh — finish a pfchatbot deployment on a PacketFence install that
# already has the code (lib/html/containers/addons pfchatbot dirs) and a
# container image. Idempotent: safe to re-run, including after PF upgrades.
#
#   bash /usr/local/pf/containers/pfchatbot/install.sh [--image TAG] [--skip-launcher]
set -u

PF=/usr/local/pf
IMAGE="pf-chatbot"
SKIP_LAUNCHER=0
while [ $# -gt 0 ]; do case "$1" in
  --image) IMAGE="$2"; shift 2 ;;
  --skip-launcher) SKIP_LAUNCHER=1; shift ;;
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
for d in lib/pfchatbot html/pfchatbot containers/pfchatbot addons/pfchatbot; do
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
!html/pfchatbot
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
  warn "created conf/pfchatbot.env from the example — EDIT IT: API_KEY, PF_PASSWORD, PF_ADMIN_URL"
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
  warn "placeholders remain in conf/pfchatbot.env — the service will start but"
  warn "chat needs a real API_KEY (or set a provider via the UI gear icon) and"
  warn "PF API calls need real PF_USERNAME/PF_PASSWORD"
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

step "6. Launcher"
if [ "$SKIP_LAUNCHER" = 1 ]; then
  ok "skipped (--skip-launcher)"
else
  bash "$PF/addons/pfchatbot/inject-launcher.sh" || warn "launcher inject failed — run it manually later"
fi

step "7. Verification"
HOST="${BIND%%:*}"; PORT="${BIND##*:}"
if [ -n "$HOST" ]; then
  if curl -s -m 10 "http://$HOST:$PORT/" | head -c 15 | grep -q '<!doctype'; then
    ok "UI serves at $HOST:$PORT"
  else
    warn "UI not answering yet — first boot embeds the RAG index (minutes);"
    warn "watch: journalctl -u $UNIT -f   until 'startup complete'"
  fi
fi
echo
echo "${B}Done.${N} Remaining manual items:"
echo "  - put real credentials in $PF/conf/pfchatbot.env if warned above, then: systemctl restart $UNIT"
echo "  - open https://<host>:1443/api/v1/pfchatbot/ (log into the admin UI first, same hostname)"
echo "  - acceptance matrix: chatbot-user read=200/write=403, chatbot-admin 200/200 (see README)"
echo "  - after any PF upgrade: re-run this script (it is idempotent) — see addons/pfchatbot/MODIFICATIONS.md"
