#!/usr/bin/env bash
# Inject the NacBot launcher into THIS host's admin dispatcher index.html.
# Idempotent. Re-run after any PF upgrade (the dist is baked into the image).
# The snippet is sourced from admin-index.html in this directory; the target
# is always the local container's own shell (bundle names are build-hashed,
# so never copy another host's index.html wholesale).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
C=httpd.admin_dispatcher
DIST=/usr/local/pf/html/pfappserver/root/dist/index.html

docker cp "$C:$DIST" /tmp/idx.html
python3 - "$HERE/admin-index.html" <<'PY'
import re, sys
snip = re.search(r'<script id="pf-chatbot-launcher">.*?</script>',
                 open(sys.argv[1]).read(), re.S).group(0)
src = open('/tmp/idx.html').read()
if 'pf-chatbot-launcher' in src:
    print('already injected; nothing to do'); raise SystemExit
open('/tmp/idx.html','w').write(src.replace('</body>', snip+'</body>', 1))
print('injected')
PY
docker cp /tmp/idx.html "$C:$DIST"
echo "done — hard-refresh the admin UI. For durability across container"
echo "re-creation, re-bake the dispatcher image (see MODIFICATIONS.md)."
