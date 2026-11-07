#!/usr/bin/env python3
"""
An example admin UI plugin service, Python standard library only.

It serves the manifest of a plugin directory (manifest.json) at
/manifest.json, and the API of its page from memory: the paths of the
manifest `api`, reached by the admin UI through the PacketFence API at
/api/v1/plugin/<name>/<path>. Optional files of the directory:
  meta.json   the answer to OPTIONS (the field metadata, eg: allowed values)
  data.json   the initial items (collection) or settings (resource)

PacketFence checked the admin and the `can` of the manifest before passing a
request. The admin is in the X-PacketFence-Username, X-PacketFence-Admin-Roles
and X-PacketFence-Admin-Actions headers, the admin token is never passed. The
answers must be JSON: PacketFence refuses anything else.

PacketFence reaches a plugin over plain HTTP only on the loopback (127.0.0.1,
::1, localhost); any other address is reached over HTTPS, with a certificate
valid for that address (--tls-cert, --tls-key).

The service does not register itself: register it with the Go or Perl
accessors (register.go, register.pl), PacketFence keeps the database
credentials.

  ./server.py hello --host 127.0.0.1 --port 8090
  ./server.py hello --port 8443 --tls-cert hello.crt --tls-key hello.key
"""
import argparse
import copy
import json
import os
import re
import ssl
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit, parse_qs, unquote

lock = threading.Lock()


def load(directory, name, default):
    path = os.path.join(directory, name)
    if not os.path.exists(path):
        return default
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def compile_path(template):
    """an api path of the manifest as a regex, {id} is one segment"""
    parts = [('(?P<id>[^/]+)' if part == '{id}' else re.escape(part)) for part in template.strip('/').split('/')]
    return re.compile('^/' + '/'.join(parts) + '/?$')


def api_path(value):
    return value if isinstance(value, str) else value['path']


class Plugin:
    def __init__(self, directory):
        self.manifest = load(directory, 'manifest.json', None)
        self.meta = load(directory, 'meta.json', {})
        self.collection = self.manifest['template'] == 'collection'
        data = load(directory, 'data.json', [] if self.collection else {})
        self.items = {item['id']: item for item in data} if self.collection else None
        self.settings = None if self.collection else data
        self.routes = [(method, compile_path(api_path(value))) for method, value in self.manifest['api'].items()]

    # the api methods of the manifest a request matches
    def methods(self, path):
        found = {}
        for method, regex in self.routes:
            match = regex.match(path)
            if match:
                found[method] = unquote(match.group('id')) if 'id' in regex.groupindex else None
        return found


class Handler(BaseHTTPRequestHandler):
    plugin = None

    def log_message(self, fmt, *args):
        sys.stderr.write('%s %s (admin %s, roles %d)\n' % (
            self.command, self.path,
            self.headers.get('X-PacketFence-Username', '-'),
            len([r for r in self.headers.get('X-PacketFence-Admin-Roles', '').split(',') if r]),
        ))

    def answer(self, status, body=None):
        data = json.dumps({'status': status, **(body or {})}).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(data)

    def body(self):
        length = int(self.headers.get('Content-Length') or 0)
        if not length:
            return {}
        try:
            return json.loads(self.rfile.read(length))
        except ValueError:
            return None

    def dispatch(self):
        p = self.plugin
        path = urlsplit(self.path).path
        if self.command in ('GET', 'HEAD') and path == '/manifest.json':
            return self.manifest()
        methods = p.methods(path)
        if not methods:
            return self.answer(404, {'message': 'Not found'})
        verb = self.command
        with lock:
            if verb == 'OPTIONS':
                return self.answer(200, {'meta': p.meta})
            if p.collection:
                return self.collection(verb, methods)
            return self.resource(verb, methods)

    def manifest(self):
        data = json.dumps(self.plugin.manifest).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(data)

    def page(self, items, cursor, limit):
        items = sorted(items, key=lambda i: str(i.get('id')))
        chunk = items[cursor:cursor + limit]
        body = {'items': copy.deepcopy(chunk), 'prevCursor': cursor, 'total_count': len(items)}
        if cursor + limit < len(items):
            body['nextCursor'] = cursor + limit
        return body

    def collection(self, verb, methods):
        p = self.plugin
        if verb == 'GET' and 'list' in methods:
            q = parse_qs(urlsplit(self.path).query)
            cursor = int((q.get('cursor') or ['0'])[0] or 0)
            limit = int((q.get('limit') or ['25'])[0] or 25)
            return self.answer(200, self.page(p.items.values(), cursor, limit))
        if verb == 'POST' and 'search' in methods:
            query = self.body() or {}
            text = json.dumps(query.get('query') or {})
            values = re.findall(r'"value": "([^"]*)"', text)
            items = [i for i in p.items.values() if all(any(v.lower() in str(f).lower() for f in i.values()) for v in values if v)]
            return self.answer(200, self.page(items, int(query.get('cursor') or 0), int(query.get('limit') or 25)))
        if verb == 'POST' and 'create' in methods:
            item = self.body()
            if not isinstance(item, dict) or not item.get('id'):
                return self.answer(422, {'message': 'An id is required', 'errors': [{'field': 'id', 'message': 'required'}]})
            if item['id'] in p.items:
                return self.answer(409, {'message': 'Item %s already exists' % item['id']})
            p.items[item['id']] = item
            return self.answer(201, {'id': item['id'], 'message': "'%s' created" % item['id']})
        item_id = methods.get('item') or methods.get('update') or methods.get('delete')
        if item_id is None:
            return self.answer(405, {'message': 'Method not allowed'})
        if item_id not in p.items:
            return self.answer(404, {'message': 'Item %s not found' % item_id})
        if verb == 'GET' and 'item' in methods:
            return self.answer(200, {'item': copy.deepcopy(p.items[item_id])})
        if verb in ('PATCH', 'PUT') and 'update' in methods:
            data = self.body()
            if not isinstance(data, dict):
                return self.answer(422, {'message': 'Invalid JSON'})
            data['id'] = item_id
            p.items[item_id] = data if verb == 'PUT' else {**p.items[item_id], **data}
            return self.answer(200, {'message': 'Settings updated'})
        if verb == 'DELETE' and 'delete' in methods:
            del p.items[item_id]
            return self.answer(200, {'message': 'Deleted %s successfully' % item_id})
        return self.answer(405, {'message': 'Method not allowed'})

    def resource(self, verb, methods):
        p = self.plugin
        if verb == 'GET' and 'item' in methods:
            return self.answer(200, {'item': copy.deepcopy(p.settings)})
        if verb in ('PATCH', 'PUT') and 'update' in methods:
            data = self.body()
            if not isinstance(data, dict):
                return self.answer(422, {'message': 'Invalid JSON'})
            p.settings = data if verb == 'PUT' else {**p.settings, **data}
            return self.answer(200, {'message': 'Settings updated'})
        return self.answer(405, {'message': 'Method not allowed'})

    do_GET = do_HEAD = do_OPTIONS = do_POST = do_PUT = do_PATCH = do_DELETE = dispatch


def main():
    parser = argparse.ArgumentParser(description='An example admin UI plugin service')
    parser.add_argument('directory', help='the plugin directory, with its manifest.json')
    parser.add_argument('--host', default='0.0.0.0')
    parser.add_argument('--port', type=int, default=8090)
    parser.add_argument('--tls-cert', help='certificate (PEM) to serve HTTPS, required unless PacketFence reaches the plugin on the loopback')
    parser.add_argument('--tls-key', help='private key (PEM) of --tls-cert')
    args = parser.parse_args()
    Handler.plugin = Plugin(args.directory)
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    scheme = 'http'
    if args.tls_cert:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(args.tls_cert, args.tls_key)
        server.socket = context.wrap_socket(server.socket, server_side=True)
        scheme = 'https'
    sys.stderr.write('plugin %s on %s://%s:%d\n' % (Handler.plugin.manifest['id'], scheme, args.host, args.port))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    main()
