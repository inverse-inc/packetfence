# PacketFence Assistant (pfchatbot)

A provider-agnostic (OpenAI/Anthropic, BYOK) chatbot for PacketFence admins:
RAG over the running version's OpenAPI spec + docs, agentic tool use against
the PF API, log triage, RADIUS test tools, per-admin conversation history in
PF's own database. Served behind the admin API at /api/v1/pfchatbot/ with
PF admin-role enforcement (CHATBOT_READ / CHATBOT_WRITE).

Tested on PacketFence 15.1 and 15.2 (containerized installs).

## Architecture

    browser -> haproxy-admin :1443 -> api-frontend (pfhttpd/caddy)
             AAA: token -> admin roles; /api/v1/pfchatbot/write/* needs
             CHATBOT_WRITE, the rest CHATBOT_READ (go/api-frontend/aaa)
             caddy handle_path strips /api/v1/pfchatbot, proxies to
             {$PF_SERVICES_URL_PFCHATBOT} (default containers-gateway.internal:8800)
          -> pf-chatbot container (FastAPI, host networking, binds internal IP only)

Two enforcement layers: the Go path-gate (by role, by path prefix) and the
app's may_write() (reads X-PacketFence-Admin-Roles, which carries ROLE NAMES).

## Install

### 0. Prerequisites
Containerized PacketFence 15.1/15.2, docker, admin credentials, an LLM API key.

### 1. Integration layer (PR 9319 content, included in this branch)
The branch patches conf/*.example templates; mirror the two hunks into the
LIVE files on the server:
- conf/caddy-services/api.conf: add the pfchatbot handle_path block ABOVE the
  /api/v1/* catch-all (copy it from api.conf.example; it sits just before the
  ldapexplorer reverse_proxy line).
- conf/adminroles.conf: append the [chatbot-user] and [chatbot-admin] roles
  (from adminroles.conf.example).

### 2. Build pfhttpd with the chatbot authz map
No Go toolchain needed on the host:

    GOVER=$(awk '/^go /{print $2}' /usr/local/pf/go/go.mod)
    docker run --rm -v /usr/local/pf:/usr/local/pf -w /usr/local/pf/go golang:${GOVER} make pfhttpd
    strings /usr/local/pf/go/pfhttpd | grep -c pfchatbot   # must be nonzero

The api-frontend image bakes the binary (no sbin mount), so overlay it:

    IMG=$(docker inspect api-frontend --format '{{.Config.Image}}')
    docker tag "$IMG" apifrontend-orig:backup
    cp /usr/local/pf/go/pfhttpd /tmp/pfhttpd-chatbot
    docker build -t "$IMG" -f - /tmp <<'DF'
    FROM apifrontend-orig:backup
    COPY pfhttpd-chatbot /usr/local/pf/sbin/pfhttpd
    DF
    /usr/local/pf/bin/pfcmd configreload hard
    systemctl restart packetfence-api-frontend packetfence-haproxy-admin

GATE: with an admin token, GET /api/v1/pfchatbot/config through :1443 must
return 502/503 (routed + authorized, backend not deployed yet). 404 = caddy
block/env missing; 401 = overlay did not take.

### 3. Database access
Zero-touch: when no CHATBOT_DB_* env is set, the service reads PacketFence's
own DB credentials (pfconfig.conf [mysql], then pf.conf [database]; template
values ignored) and connects over the mounted MySQL socket as 'pf'@'localhost'.

One-time install grant: store.init() creates its tables (chatbot_thread,
chatbot_message, ... singular names) on first boot, and PF's localhost grant
lacks DDL by default (it already holds DROP + full DML, so this is not a
meaningful widening):

    mysql -S /var/lib/mysql/mysql.sock -e \
      "GRANT CREATE, ALTER, INDEX ON pf.* TO 'pf'@'localhost'; FLUSH PRIVILEGES;"

Hardened alternative: create a dedicated user and set the CHATBOT_DB_* block
in the env (see pfchatbot.env.example).

### 4. Deploy the service
    PF=/usr/local/pf
    cp -a <clone>/lib/pfchatbot        $PF/lib/
    cp -a <clone>/html/pfchatbot       $PF/html/
    cp -a <clone>/containers/pfchatbot $PF/containers/
    cp -a <clone>/addons/pfchatbot     $PF/addons/

Build-context allowlist (REQUIRED, not committed upstream — a root .dockerignore
would affect every other build in the repo):

    cat > $PF/.dockerignore <<'DI'
    *
    !lib/pfchatbot
    !html/pfchatbot
    !containers/pfchatbot
    containers/pfchatbot/docs
    DI

### 5. Environment
Copy lib/pfchatbot/pfchatbot.env.example to /usr/local/pf/conf/pfchatbot.env, fill it in,
create /usr/local/pf/conf/pfchatbot-testtool.env (see example), chmod 600 both.

HARD REQUIREMENTS learned the hard way:
- BIND_HOST: set it EXPLICITLY to the internal container-gateway IP
  (docker exec api-frontend getent hosts containers-gateway.internal).
  BIND_HOST=auto picks the PF management IP; on hosts where that is public,
  the bot listens on the internet with no authentication in front.
- CHATBOT_USER_HEADER=X-PacketFence-Username and
  CHATBOT_REQUIRE_WRITE_ACTION=1 behind the admin proxy.
- docker --env-file has NO inline-comment syntax: comments on their own lines.

### 6. Docs corpus + first boot
    DOCS_DIR=$PF/containers/pfchatbot/docs bash $PF/lib/pfchatbot/fetch_docs.sh
    cd $PF && bash containers/pfchatbot/rebuild.sh   # installs the systemd unit on first run

First boot downloads the embedding model and builds the RAG index (minutes);
journalctl -u packetfence-chatbot -f until "startup complete". Restarts load
from cache in ~1s.

### 7. Admin-UI launcher
    bash $PF/addons/pfchatbot/inject-launcher.sh

Injects the NacBot button into THIS host's admin dispatcher index.html.
Never copy another host's index.html: the SPA bundle names are build-hashed
per image.

## Acceptance test
Create an admin per role and run (TOK = that user's /api/v1/login token):

    # read:  POST /api/v1/pfchatbot/chat            -> reply
    # write: POST /api/v1/pfchatbot/write/models    -> see matrix

    role          read    write
    chatbot-user   200     403  (denied by the Go layer: "lacking the
                                 CHATBOT_WRITE administrative role")
    chatbot-admin  200     200
    ALL (admin)    200     200

Plus: the UI at https://<host>:1443/api/v1/pfchatbot/ (log into the admin UI
first, SAME hostname — token lives per-origin), Run test (exercises the
testtool helper), file upload/download.

## Upgrades
A PF upgrade re-pulls image tags and replaces packaged files. Re-apply per
addons/pfchatbot/MODIFICATIONS.md: the api-frontend binary overlay, the
dispatcher index.html inject, and the live api.conf/adminroles.conf mirrors.
The pfchatbot directories themselves are unowned and survive.
