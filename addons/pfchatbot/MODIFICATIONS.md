# Local modifications a PacketFence upgrade will clobber

PF upgrades re-pull container image tags and overwrite packaged files.
Everything below must be re-applied after an upgrade. The pfchatbot
directories (lib/, html/, containers/, addons/) are unowned and survive.

## 1. api-frontend image: pfhttpd binary overlay
Carries the chatbot authz map (go/api-frontend/aaa/authorization.go).
Rebuild + overlay per README step 2. Backup tag: apifrontend-orig:backup.
Check: docker exec api-frontend sh -c 'strings /usr/local/pf/sbin/pfhttpd | grep -c pfchatbot'

## 2. httpd.admin_dispatcher image: launcher inject
dist/index.html gets the NacBot <script>. Re-run inject-launcher.sh, then
for durability:
    IMG=$(docker inspect httpd.admin_dispatcher --format '{{.Config.Image}}')
    docker tag "$IMG" admin-dispatcher-orig:backup
    docker cp httpd.admin_dispatcher:/usr/local/pf/html/pfappserver/root/dist/index.html /tmp/idx.html
    docker build -t "$IMG" -f - /tmp <<'DF'
    FROM admin-dispatcher-orig:backup
    COPY idx.html /usr/local/pf/html/pfappserver/root/dist/index.html
    DF
    systemctl restart packetfence-httpd.admin_dispatcher

## 3. Live config mirrors (packaged files, overwritten on upgrade)
- conf/caddy-services/api.conf: pfchatbot handle_path block above the
  /api/v1/* catch-all (source: api.conf.example in this branch)
- conf/adminroles.conf: [chatbot-user] + [chatbot-admin] (source:
  adminroles.conf.example)
Then: pfcmd configreload hard; restart api-frontend + haproxy-admin.

## 4. Host-level, upgrade-safe but undocumented elsewhere
- /usr/local/pf/.dockerignore (allowlist; required for the pfchatbot build)
- /usr/local/pf/conf/pfchatbot.env, pfchatbot-testtool.env (secrets, 600)
- MariaDB user 'pfchatbot'@'localhost'
- pf-chatbot image (built locally by containers/pfchatbot/rebuild.sh);
  pre-change backup convention: pfchatbot-premigration:backup
