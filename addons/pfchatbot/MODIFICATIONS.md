# Local modifications a PacketFence upgrade will clobber

PF upgrades re-pull container image tags and overwrite packaged files.
Everything below must be re-applied after an upgrade. The pfchatbot
directories (lib/, containers/, addons/) are unowned and survive.

## 1. api-frontend image: pfhttpd binary overlay
Carries the chatbot authz map (go/api-frontend/aaa/authorization.go).
Rebuild + overlay per README step 2. Backup tag: apifrontend-orig:backup.
Check: docker exec api-frontend sh -c 'strings /usr/local/pf/sbin/pfhttpd | grep -c pfchatbot'

## 2. httpd.admin_dispatcher image: admin UI
The assistant UI is part of the pfappserver SPA (views/Assistant). Until a PF
release ships it, the dispatcher image needs a dist built from this branch.

## 3. Live config mirrors (packaged files, overwritten on upgrade)
- conf/caddy-services/api.conf: pfchatbot handle_path block above the
  /api/v1/* catch-all (source: api.conf.example in this branch)
- conf/adminroles.conf: [chatbot-user] + [chatbot-admin] (source:
  adminroles.conf.example)
Then: pfcmd configreload hard; restart api-frontend + haproxy-admin.

## 4. Host-level, upgrade-safe but undocumented elsewhere
- /usr/local/pf/.dockerignore (allowlist; required for the pfchatbot build)
- /usr/local/pf/conf/pfchatbot.env, pfchatbot-testtool.env (wiring/fallbacks, 600)
- pf.conf [pfchatbot] (provider, key, model, PF API account): kept across
  upgrades like the rest of pf.conf
- MariaDB user 'pfchatbot'@'localhost'
- pf-chatbot image (built locally by containers/pfchatbot/rebuild.sh);
  pre-change backup convention: pfchatbot-premigration:backup
