#!/usr/bin/env bash
# rebuild.sh -- build the image, verify it, THEN restart. In that order.
#
# systemctl restart happily starts whatever image already exists, so a build
# that never ran (or failed) looks exactly like a runtime fault. This refuses
# to restart unless the image it just built is the one it expects.
set -uo pipefail
cd "$(dirname "$0")" || exit 1

B=$(tput bold 2>/dev/null||true); N=$(tput sgr0 2>/dev/null||true)
step(){ echo; echo "${B}==> $*${N}"; }
ok(){ echo "  ok    $*"; }
bad(){ echo "  FAIL  $*" >&2; }

step "1. Checking the Dockerfile is well-formed"
grep -q "$(printf '\r')" Dockerfile && { bad "Dockerfile has CRLF line endings"; exit 1; }
for kw in ENTRYPOINT CMD; do
  line="$(grep -m1 "^$kw " Dockerfile)"
  # Only the directive lines must be pure ASCII. Comments may legitimately
  # contain em-dashes; a smart quote HERE is what makes docker silently fall
  # back to shell form, which is the bug this whole script exists to catch.
  if printf '%s' "$line" | LC_ALL=C grep -q '[^ -~]'; then
    bad "$kw contains non-ASCII characters (smart quotes from a copy/paste)"
    printf '        %s\n' "$(printf '%s' "$line" | cat -v)" >&2
    echo "        Fix: scp the file instead of pasting it into an editor." >&2
    exit 1
  fi
  case "$line" in
    *'["'*'"]'*) ok "$kw is exec form: $line" ;;
    *) bad "$kw is NOT valid exec form -- docker will fall back to /bin/sh -c"
       echo "        got: $line" >&2; exit 1 ;;
  esac
done

step "2. Checking the files the image needs are present"
missing=0
for f in containers/pfchatbot/supervisor.sh lib/pfchatbot/app.py lib/pfchatbot/store.py lib/pfchatbot/prompts.py lib/pfchatbot/tools.py lib/pfchatbot/pf-testtool-helper.py containers/pfchatbot/requirements.txt html/pfchatbot/index.html; do
  if [ -s "/usr/local/pf/$f" ]; then ok "$f"; else bad "$f missing or empty"; missing=1; fi
done
[ "$missing" = 0 ] || exit 1
sh -n supervisor.sh || { bad "supervisor.sh has a syntax error"; exit 1; }
ok "supervisor.sh parses"

step "3. Building"
if ! docker build -t pf-chatbot -f /usr/local/pf/containers/pfchatbot/Dockerfile /usr/local/pf 2>&1 | tail -25; then
  bad "build failed -- NOT restarting; the old container keeps running"
  exit 1
fi

step "4. Verifying the image actually has the new entrypoint"
CMD_JSON="$(docker image inspect pf-chatbot --format '{{json .Config.Cmd}}' 2>/dev/null)"
ENT_JSON="$(docker image inspect pf-chatbot --format '{{json .Config.Entrypoint}}' 2>/dev/null)"
echo "  Entrypoint: $ENT_JSON"
echo "  Cmd       : $CMD_JSON"
case "$CMD_JSON" in
  *supervisor.sh*) ok "image runs supervisor.sh" ;;
  *) bad "image does NOT run supervisor.sh -- it is stale or the build did not take"; exit 1 ;;
esac
case "$CMD_JSON" in
  *'\"['*|*'[\"['*) bad "Cmd is a shell string, not an array -- the CMD line is malformed"; exit 1 ;;
esac
docker run --rm --entrypoint /bin/sh pf-chatbot -c 'test -s /app/supervisor.sh && echo "  ok    /app/supervisor.sh is in the image ($(wc -c </app/supervisor.sh) bytes)"' \
  || { bad "/app/supervisor.sh is not inside the image"; exit 1; }

step "5. Restarting"
UNIT=packetfence-chatbot
# First run after the rename: install the unit if it is not there yet, and
# retire the pre-rename pf-chatbot.service -- both would fight over the same
# container name.
if [ ! -f "/etc/systemd/system/$UNIT.service" ]; then
  if [ -f "/usr/local/pf/containers/pfchatbot/$UNIT.service" ]; then
    install -m 0644 "/usr/local/pf/containers/pfchatbot/$UNIT.service" "/etc/systemd/system/$UNIT.service" && ok "installed $UNIT.service"
  else
    bad "/etc/systemd/system/$UNIT.service is missing and ./$UNIT.service is not here to install"; exit 1
  fi
fi
if systemctl list-unit-files 2>/dev/null | grep -q '^pf-chatbot\.service'; then
  systemctl disable --now pf-chatbot.service >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/pf-chatbot.service
  ok "retired the old pf-chatbot.service (renamed to $UNIT)"
fi
systemctl daemon-reload
systemctl reset-failed "$UNIT" 2>/dev/null || true
systemctl enable "$UNIT" >/dev/null 2>&1 || true
systemctl restart "$UNIT"
sleep 4
if systemctl is-active --quiet "$UNIT"; then
  ok "service is active"
  echo
  # docker may be configured with the journald log driver, in which case
  # `docker logs` cannot read; the journal is where the output lives anyway.
  if ! docker logs --tail 25 pf-chatbot 2>/dev/null | sed 's/^/  /'; then
    journalctl -u "$UNIT" -n 25 --no-pager -o cat | sed 's/^/  /'
  fi
else
  bad "service did not come up"
  journalctl -u "$UNIT" -n 25 --no-pager | sed 's/^/  /'
  exit 1
fi
