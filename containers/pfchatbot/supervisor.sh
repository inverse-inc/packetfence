#!/bin/sh
# Runs the two processes that used to be separate units.
#
#   pf-testtool-helper  as pfhelper  -- the only identity that may exec the
#                                     tools (root:pfhelper 0750). Its PRIMARY
#                                     group is pfbot so the socket it creates
#                                     is pfhelper:pfbot 0660 and the app can
#                                     connect; pfhelper is a supplementary
#                                     group so it can still exec the tools.
#   uvicorn (app)       as pfbot     -- unchanged
#
# The helper is restarted on its own if it dies, so a helper crash degrades the
# test-tools panel instead of taking the assistant down with it. If the APP
# exits, the container exits, and systemd restarts it.
set -eu

# With --network host there is no -p mapping, so BIND_HOST is the only control
# over who can reach the assistant. Set it explicitly in .env to pin it.
#
# "auto" picks, in order:
#   1. the PacketFence management IP (host of PF_ADMIN_URL) -- the address you
#      already reach the admin UI on, reachable from your browser AND from the
#      other PF containers (needed later for the caddy /api/v1/pfchatbot route)
#   2. 100.64.0.1, PacketFence's internal host address (containers only)
#   3. 127.0.0.1
# It never picks 0.0.0.0. Whatever it binds is reachable by anything that can
# route to that address, so keep 8800 firewalled from outside the management
# network -- the identity header is only trustworthy behind the PF proxy.
_addr_present() { ip -4 -o addr show 2>/dev/null | grep -q "inet ${1}/"; }
if [ "${BIND_HOST:-auto}" = "auto" ]; then
  mgmt="$(printf '%s' "${PF_ADMIN_URL:-}" | sed -n 's|^[a-z]*://\([^:/]*\).*|\1|p')"
  if [ -n "$mgmt" ] && _addr_present "$mgmt"; then
    BIND_HOST="$mgmt"
  elif _addr_present 100.64.0.1; then
    BIND_HOST=100.64.0.1
  else
    BIND_HOST=127.0.0.1
  fi
  export BIND_HOST
fi
echo "[pf-bot] binding ${BIND_HOST}:${BIND_PORT}" >&2

# Under --network host the container shares the host's network, so the PF API
# is on 127.0.0.1 and the bridge-mode alias host.docker.internal may not
# resolve. Rewrite it instead of failing later with "Name or service not known".
for v in PF_BASE_URL PF_OPENAPI_URL; do
  eval "val=\${$v:-}"
  case "$val" in
    *host.docker.internal*)
      if ! getent hosts host.docker.internal >/dev/null 2>&1; then
        newval="$(printf '%s' "$val" | sed 's/host\.docker\.internal/127.0.0.1/')"
        export "$v=$newval"
        echo "[pf-bot] $v: host.docker.internal does not resolve here; using $newval" >&2
      fi ;;
  esac
done

HELPER_SOCK="${PF_TESTTOOL_SOCK:-/run/pf-testtool/helper.sock}"
HELPER_DIR="$(dirname "$HELPER_SOCK")"

# Create and own the socket directory HERE, as root, at runtime.
#
# Doing it in the Dockerfile is not enough: /run does not reliably survive into
# the running container, so the directory was either missing (FileNotFoundError)
# or root-owned and unwritable by pfhelper (PermissionError) -- which is exactly
# how the helper crash-looped. Getting it right needs root, and this script is
# the last point at which we still have it.
mkdir -p "$HELPER_DIR"

# Idempotent. If the directory is already pfhelper:pfbot 770 -- e.g. left that
# way by an image layer -- there is nothing to do, and TRYING would fail: root
# without CAP_FOWNER cannot chmod a directory it does not own, and this
# container deliberately lacks that capability. Only a root-owned directory is
# fixed up, and in the order that needs CAP_CHOWN alone: chmod while root still
# owns it, chown last.
cur="$(stat -c '%U:%G %a' "$HELPER_DIR" 2>/dev/null || echo '?')"
if [ "$cur" = "pfhelper:pfbot 770" ]; then
  : # already correct
elif [ "${cur%% *}" = "root:root" ] || [ "${cur%%:*}" = "root" ]; then
  chmod 0770 "$HELPER_DIR" || { echo "[pf-bot] FATAL: chmod $HELPER_DIR failed" >&2; exit 1; }
  chown pfhelper:pfbot "$HELPER_DIR" || {
    echo "[pf-bot] FATAL: cannot chown $HELPER_DIR. The container needs CAP_CHOWN" >&2
    echo "[pf-bot]        (and CAP_SETUID/CAP_SETGID for setpriv) -- check the" >&2
    echo "[pf-bot]        --cap-add flags in pf-chatbot.service." >&2
    exit 1; }
else
  echo "[pf-bot] FATAL: $HELPER_DIR is $cur; expected pfhelper:pfbot 770 or root-owned." >&2
  echo "[pf-bot]        Without CAP_FOWNER this cannot be repaired at runtime -- rebuild" >&2
  echo "[pf-bot]        the image, or fix the mount on that path." >&2
  exit 1
fi
# a stale socket from an earlier run is removed by the helper itself (it owns it)
if ! setpriv --reuid=pfhelper --regid=pfbot --groups=pfhelper \
       test -w "$HELPER_DIR"; then
  echo "[pf-bot] FATAL: $HELPER_DIR is not writable by pfhelper; the test tools" >&2
  echo "[pf-bot]        would crash-loop. Check the mounts on that path." >&2
  exit 1
fi
echo "[pf-bot] helper socket dir $HELPER_DIR ready ($(stat -c '%U:%G %a' "$HELPER_DIR"))" >&2

helper_loop() {
  while true; do
    setpriv --reuid=pfhelper --regid=pfbot --groups=pfhelper \
      /usr/local/bin/python3 /app/pf-testtool-helper.py || \
      echo "[pf-bot] test-tool helper exited ($?), restarting in 5s" >&2
    sleep 5
  done
}
helper_loop &
HELPER_PID=$!

term() { kill -TERM "$HELPER_PID" 2>/dev/null || true; }
trap term TERM INT

# The app reads PacketFence's logs from a read-only mount. Docker's --group-add
# put the log group on THIS (root) process, but --init-groups would rebuild
# pfbot's groups from the container's /etc/group, which knows nothing of that
# gid -- silently dropping log access, so every diagnose reports "no matches".
# Hand down the group that owns the mounted log dir, plus anything else docker
# added (never the root group).
LOGDIR="${PF_LOG_DIR:-/pflogs}"
APP_GROUPS="pfbot"
_add_group() { case ",$APP_GROUPS," in *",$1,"*) ;; *) APP_GROUPS="$APP_GROUPS,$1" ;; esac; }
if [ -d "$LOGDIR" ]; then
  lg="$(stat -c %g "$LOGDIR" 2>/dev/null || true)"
  [ -n "$lg" ] && [ "$lg" != 0 ] && _add_group "$lg"
fi
for g in $(id -G); do [ "$g" != 0 ] && _add_group "$g"; done
if [ -d "$LOGDIR" ]; then
  if setpriv --reuid=pfbot --regid=pfbot --groups="$APP_GROUPS" test -r "$LOGDIR"; then
    echo "[pf-bot] log dir $LOGDIR readable by the app (groups: $APP_GROUPS)" >&2
  else
    echo "[pf-bot] WARNING: $LOGDIR is NOT readable by the app -- diagnose and log" >&2
    echo "[pf-bot]          search will find nothing. Check --group-add in the unit" >&2
    echo "[pf-bot]          matches the group owning /usr/local/pf/logs." >&2
  fi
fi

# the app is the container's main process: exec so it gets the signals directly
setpriv --reuid=pfbot --regid=pfbot --groups="$APP_GROUPS" \
  /usr/local/bin/python3 -m uvicorn app:app --host "${BIND_HOST}" --port "${BIND_PORT}" &
APP_PID=$!
wait "$APP_PID"
RC=$?
term
exit "$RC"
