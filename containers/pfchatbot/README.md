# NACBot (pfchatbot)

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

## Repository layout

    lib/pfchatbot/                        # the Python service
      app.py                              #   FastAPI app: agent loop, write guard,
                                          #   /chat /write/* JSON endpoints (no UI)
      pfconf.py                           #   pf.conf [pfchatbot] settings, env fallback
      store.py                            #   conversation store (PF MariaDB, socket;
                                          #   zero-touch credential fallback)
      prompts.py  tools.py                #   system prompt + tool schemas
      pf-testtool-helper.py               #   host-side RADIUS/capture helper (unix socket)
      fetch_docs.sh                       #   pulls version-matched PF guides for RAG
      providers/                          #   openai / anthropic (BYOK)
      rag/                                #   corpus chunking, fastembed index, reranker
      pfchatbot.env.example               #   env template
      pfchatbot-testtool.env.example
    html/pfappserver/root/src/views/
      Assistant/                          # the UI, part of the admin SPA (/#/assistant)
      Configuration/pfchatbot/            # settings page (Integration > NACBot)
    containers/pfchatbot/
      Dockerfile  requirements.txt        # python:3.12-slim + test tools, dual users
      supervisor.sh                       #   runs helper (pfhelper) + app (pfbot); safe
                                          #   auto-bind via containers-gateway.internal
      rebuild.sh                          #   verify -> build -> verify image -> restart
      packetfence-chatbot.service         #   systemd unit (docker run, mounts, caps)
      README.md                           #   this file
    addons/pfchatbot/
      MODIFICATIONS.md                    #   what PF upgrades clobber + re-apply steps

    # PR-9319 integration (edits to existing PF files, included in this branch):
    conf/pf.conf.defaults                 # [services_url] pfchatbot=...gateway:8800,
                                          #   [pfchatbot] settings (+ documentation.conf)
    conf/caddy-services/api.conf.example  # handle_path /api/v1/pfchatbot/* block
    conf/adminroles.conf.example          # [chatbot-user] / [chatbot-admin]
    go/api-frontend/aaa/authorization.go  # path -> CHATBOT_READ / CHATBOT_WRITE map
    lib/pf/constants/admin_roles.pm       # the two actions
    lib/pf/services/manager/roles/env_golang_service.pm  # services_url -> Go env

Deliberately NOT in the repo (created at install): conf/pfchatbot*.env (secrets),
containers/pfchatbot/docs/ (generated), /usr/local/pf/.dockerignore, and the
live api.conf / adminroles.conf mirrors.

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
    cp -a <clone>/containers/pfchatbot $PF/containers/
    cp -a <clone>/addons/pfchatbot     $PF/addons/

Build-context allowlist (REQUIRED, not committed upstream — a root .dockerignore
would affect every other build in the repo):

    cat > $PF/.dockerignore <<'DI'
    *
    !lib/pfchatbot
    !containers/pfchatbot
    containers/pfchatbot/docs
    DI

### 5. Settings and environment
Provider, API key, model, the PF API account and the tuning knobs live in the
[pfchatbot] section of pf.conf: set them in Configuration > Integration >
NACBot (/api/v1/config/base/pfchatbot). Provider/key/model apply
on the next request; the rest on a service restart. The unit mounts the whole
conf/ dir read-only because pf.conf is rewritten by rename, which a single-file
bind mount never sees.

Copy lib/pfchatbot/pfchatbot.env.example to /usr/local/pf/conf/pfchatbot.env
(deployment wiring + fallbacks for anything pf.conf leaves empty), create
/usr/local/pf/conf/pfchatbot-testtool.env (see example), chmod 600 both.

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

### 7. Admin UI
The assistant is a view of the admin SPA (html/pfappserver): the navbar icon
opens /admin/#/assistant for admins holding CHATBOT_READ. It ships with the
pfappserver build; nothing is injected.

## Acceptance test
Create an admin per role and run (TOK = that user's /api/v1/login token):

    # read:  POST /api/v1/pfchatbot/chat            -> reply
    # write: POST /api/v1/pfchatbot/write/settings/test -> see matrix

    role          read    write
    chatbot-user   200     403  (denied by the Go layer: "lacking the
                                 CHATBOT_WRITE administrative role")
    chatbot-admin  200     200
    ALL (admin)    200     200

## Permission model

Four gates sit between an admin and a chatbot write:

    Gate 0  navbar entry       shown only with CHATBOT_READ ('read chatbot');
                               write controls disabled without CHATBOT_WRITE
    Gate 1  read anything      Go AAA: /api/v1/pfchatbot/*  needs CHATBOT_READ
    Gate 2  write endpoints    Go AAA: /api/v1/pfchatbot/write/*  needs CHATBOT_WRITE
    Gate 3  app-level check    may_write(): forwarded ROLE NAME must be in
                               {CHATBOT-ADMIN, ALL, ALL_PF_ONLY, ...}
                               (X-PacketFence-Admin-Roles carries role names;
                               override the set with CHATBOT_WRITE_GRANTS)
    always  confirmation card  no write executes without a human click; the
                               model can only STAGE changes

    admin role          navbar  read/chat  writes   note
    ALL                   yes      yes       yes    superset everywhere
    ALL_PF_ONLY           yes      yes       yes    PF-scoped superset
    chatbot-admin         yes      yes       yes    the intended writer role
    chatbot-user          yes      yes       403    read-only by design
    other roles only      no       401       401

Role grants are additive-only (no deny): combinations union, so
ALL + anything behaves as ALL — which is why acceptance tests need
single-role test users.

A bare chatbot-user can reach the assistant by URL but can barely render
the admin UI around it (other pages need their own read actions). The
realistic read-only persona is chatbot-user plus a few read actions
(NODES_READ, USERS_READ, ...).

Plus: the UI at https://<host>:1443/admin/#/assistant, Run test (exercises
the testtool helper), file upload/download.

## Upgrades
A PF upgrade re-pulls image tags and replaces packaged files. Re-apply per
addons/pfchatbot/MODIFICATIONS.md: the api-frontend binary overlay and the
live api.conf/adminroles.conf mirrors.
The pfchatbot directories themselves are unowned and survive.
