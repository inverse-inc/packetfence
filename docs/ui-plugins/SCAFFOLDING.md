# Creating an admin UI plugin from scratch

This guide builds a plugin service step by step, with a complete example in
each language:

- Go: [`examples/go-plugin`](examples/go-plugin) (`main.go`, `manifest.json`)
- Perl: [`examples/perl-plugin`](examples/perl-plugin) (`plugin.pl`, `manifest.json`)

Both serve the same page, a collection of notes kept in memory, and both were
run against the PacketFence API: list, search, paging, create, update and
delete, registration at startup, deregistration on SIGTERM. Copy one and
rename it. The reference for every property is [`README.md`](README.md).

## What a plugin is

A plugin is an HTTP service of your own, with three parts:

| Part | What it does |
|---|---|
| `manifest.json` | describes the page: where it goes in the menu, the ACL, the API paths, the form. Only the core components and validators can be used, no code reaches the UI |
| the API of the page | the paths the manifest names, answering JSON in the format of the PacketFence API |
| the registration | tells PacketFence the name, host and port of the service when it starts, removes it when it stops |

PacketFence fetches the manifest, adds the page to the admin UI, and passes
the calls of the page to the service through `/api/v1/plugin/<name>/<path>`,
after checking the admin and the ACL of the manifest.

## Checklist

1. Pick a **name**: `^[a-z][a-z0-9_-]{0,62}$`, it is the `id` of the manifest,
   the URL segment `/api/v1/plugin/<name>/` and the key of the registration.
2. Pick the **admin roles** the page needs, among the existing ones (a plugin
   cannot add roles): a target and its actions, eg `SYSLOG_READ`,
   `SYSLOG_CREATE`, `SYSLOG_UPDATE`, `SYSLOG_DELETE` are written
   `read syslog`, `create syslog`, … in the manifest.
3. Write the **manifest**, and check it against
   [`manifest.schema.json`](manifest.schema.json).
4. Write the **API**: one route per method of the manifest.
5. Decide **where it runs** and how PacketFence reaches it: plain HTTP on the
   loopback of api-frontend only, HTTPS with a trusted certificate otherwise.
6. **Register** at startup, **deregister** on SIGTERM, with the Go or Perl
   accessors. The service never handles the database credentials.
7. Run it as a **service** (systemd unit, Kubernetes deployment).
8. **Test** it through the PacketFence API.

## 1. Layout

```
notes-go/                         notes-perl/
├── go.mod                        ├── manifest.json
├── main.go                       ├── plugin.pl
├── manifest.json (embedded)      └── notes-perl.service
└── notes-go.service
```

## 2. The manifest

The manifest of the examples ([`examples/go-plugin/manifest.json`](examples/go-plugin/manifest.json)):

```json
{
  "manifestVersion": 1,
  "id": "notes-go",
  "title": { "en": "Notes (go plugin)", "fr": "Notes (plugin go)" },
  "menu": { "area": "configuration", "section": "/configuration/integration", "can": "read syslog" },
  "template": "collection",
  "api": {
    "list": "notes",
    "listOptions": "notes",
    "search": "notes/search",
    "create": { "path": "notes", "can": "create syslog" },
    "item": "notes/{id}",
    "itemOptions": "notes/{id}",
    "update": { "path": "notes/{id}", "can": "update syslog" },
    "delete": { "path": "notes/{id}", "can": "delete syslog" }
  },
  "collection": {
    "columns": [ { "key": "id", "label": { "en": "Name" }, "sortable": true }, { "key": "text", "label": { "en": "Text" } } ],
    "searchFields": ["id", "text"]
  },
  "form": {
    "fields": [
      { "namespace": "id", "component": "BaseFormGroupInput", "label": { "en": "Name" },
        "validators": [ { "fn": "required" }, { "fn": "matches", "args": ["^[a-z0-9-]+$"] } ] },
      { "namespace": "text", "component": "BaseFormGroupTextarea", "label": { "en": "Text" },
        "validators": [ { "fn": "required" } ] }
    ]
  }
}
```

The rules that are easy to miss:

- `menu.can` is **required**, and so is the `can` of `create`, `update` and
  `delete`: the API checks them on every call to the plugin.
- `id` equals the registered name.
- An API path is relative to the plugin, has one `{id}` at most, and
  `search` cannot have the path of `create`.
- `template: "resource"` is one object (a settings page): `item` (GET),
  `itemOptions`, `update`; the paths have no `{id}`.

Check it before running anything, with any JSON Schema 2020-12 validator, eg:

```
npm i ajv@8
node -e '
const Ajv = require("ajv/dist/2020").default, fs = require("fs")
const v = new Ajv({ strict: false }).compile(JSON.parse(fs.readFileSync("docs/ui-plugins/manifest.schema.json")))
console.log(v(JSON.parse(fs.readFileSync("manifest.json"))) || v.errors)'
```

The API applies a few more checks (validator types, `when` fields): a
manifest it refuses is logged by api-frontend, see [Troubleshooting](#8-troubleshooting).

## 3. The API contract

| Method of the manifest | Request | Answer |
|---|---|---|
| `list` | `GET /notes?cursor=&limit=&sort=&fields=` | `{ "items": [...], "nextCursor": n, "prevCursor": n, "total_count": n }`, no `nextCursor` on the last page |
| `search` | `POST /notes/search`, `{ "query": {...}, "cursor": n, "limit": n, "sort": [...], "fields": [...] }` | like `list` |
| `listOptions`, `itemOptions` | `OPTIONS /notes`, `OPTIONS /notes/<id>` | `{ "meta": { "<field>": { "allowed": [{ "value", "text" }], "default": … } } }`, `{ "meta": {} }` is fine |
| `item` | `GET /notes/<id>` | `{ "item": {...} }`, 404 when it does not exist |
| `create` | `POST /notes`, the item | 201 `{ "id": "…", "message": "…" }`, 409 when it exists |
| `update` | `PATCH /notes/<id>`, the item | 200 `{ "message": "…" }` |
| `delete` | `DELETE /notes/<id>` | 200 `{ "message": "…" }` |
| errors | | `{ "message": "…", "errors": [{ "field": "<namespace>", "message": "…" }] }` with 4xx: the field errors show under the form fields |

What PacketFence guarantees and expects:

- **Only these calls reach the service.** The path and verb must be a method
  of the manifest, and the admin must satisfy `menu.can` and the `can` of
  the method. The service still validates its input.
- **The admin, not their token.** Use these headers, never anything from the
  client:

  | Header | Content |
  |---|---|
  | `X-PacketFence-Username` | the admin |
  | `X-PacketFence-Admin-Roles` | their admin roles (eg `ALL`) |
  | `X-PacketFence-Admin-Actions` | their actions on the targets the manifest names (eg `SYSLOG_READ,SYSLOG_UPDATE`); check the `can` of a field or a tab here, the UI only hides them |
- **JSON only.** Any other answer, a redirect, a 401/407 or more than 10 MB
  is turned into a 502. Your headers (cookies, CORS, …) are not passed.
- **Texts are text.** `message`, `errors` and `warnings` are shown escaped:
  HTML in them is displayed, not rendered.

## 4. Go

Full code: [`examples/go-plugin/main.go`](examples/go-plugin/main.go).

**Module.** The accessors are in `github.com/inverse-inc/packetfence/go/uiplugins`.

- In the PacketFence tree, put the plugin under `go/cmd/<name>/` and it builds
  with the PacketFence module.
- In a repository of its own:

  ```
  module example.com/notes-go

  go 1.26.4

  require github.com/inverse-inc/packetfence/go v0.0.0
  replace github.com/inverse-inc/packetfence/go => /path/to/packetfence/go
  ```

  or a `go.work` with `use ( . /path/to/packetfence/go )`.

**The skeleton:**

```go
//go:embed manifest.json
var manifest []byte

func routes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /manifest.json", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write(manifest)
	})
	mux.HandleFunc("GET /notes", list)          // list
	mux.HandleFunc("POST /notes/search", search) // search
	mux.HandleFunc("POST /notes", create)       // create
	mux.HandleFunc("GET /notes/{id}", item)     // item
	mux.HandleFunc("PATCH /notes/{id}", update) // update
	mux.HandleFunc("DELETE /notes/{id}", remove) // delete
	mux.HandleFunc("OPTIONS /notes", options)    // listOptions
	mux.HandleFunc("OPTIONS /notes/{id}", options) // itemOptions
	return mux
}

func main() {
	listener, _ := net.Listen("tcp", "127.0.0.1:8092")
	server := &http.Server{Handler: routes()}
	go server.Serve(listener) // or ServeTLS, see 6.

	// register once the service answers
	r := uiplugins.Registration{Name: "notes-go", Host: "127.0.0.1", Port: 8092}
	if err := uiplugins.Register(ctx, r); err != nil {
		log.Fatal(err)
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, syscall.SIGINT)
	<-stop
	uiplugins.Deregister(ctx, r.Name)
	server.Shutdown(ctx)
}
```

**Build and run:**

```
go build -o notes-go .
./notes-go -listen 127.0.0.1:8092
./notes-go -listen 0.0.0.0:8443 -host containers-gateway.internal -port 8443 -tls-cert notes.crt -tls-key notes.key
```

`uiplugins.Register` reads the database settings from pfconfig, like the other
PacketFence Go services: `PFCONFIG_PROTO`, `PFCONFIG_TCP_HOST` and
`PFCONFIG_TCP_PORT` in the environment, and `PF_SYSTEM_INIT_KEY` or
`conf/system_init_key`. `-register=false` starts the service without
registering, for a registration done by `register.pl`.

## 5. Perl

Full code: [`examples/perl-plugin/plugin.pl`](examples/perl-plugin/plugin.pl).

**Dependencies.** The plugin runs with the Perl of PacketFence, which ships
Mojolicious, on a host or in a container that has the PacketFence tree
(`/usr/local/pf/lib`, `/usr/local/pf/lib_perl`) and reaches pfconfig.

**The skeleton:**

```perl
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use Mojolicious::Lite;
use Mojo::Server::Daemon;
use pf::error qw(is_error);
use pf::ui_plugins;

get '/manifest.json' => sub { my ($c) = @_; $c->res->headers->content_type('application/json'); $c->render(data => $manifest) };
get     '/notes'        => \&list;     # list
post    '/notes/search' => \&search;   # search
post    '/notes'        => \&create;   # create
get     '/notes/:id'    => \&item;     # item
patch   '/notes/:id'    => \&update;   # update
del     '/notes/:id'    => \&remove;   # delete
options '/notes'        => sub { $_[0]->render(json => { meta => {} }) };

my $daemon = Mojo::Server::Daemon->new(app => app, listen => ['http://127.0.0.1:8093']);
$daemon->start;

# register once the service answers
my %registration = (name => 'notes-perl', host => '127.0.0.1', port => 8093);
my ($status, $error) = pf::ui_plugins::register(\%registration);
die "$error\n" if is_error($status);

my $stop = sub { pf::ui_plugins::deregister('notes-perl'); Mojo::IOLoop->stop };
local $SIG{TERM} = $stop;
local $SIG{INT}  = $stop;
Mojo::IOLoop->recurring(1 => sub { }); # let Perl deliver the signals
Mojo::IOLoop->start;
```

**Run:**

```
/usr/local/pf/docs/ui-plugins/examples/perl-plugin/plugin.pl --listen http://127.0.0.1:8093
plugin.pl --listen 'https://0.0.0.0:8443?cert=notes.crt&key=notes.key' --host containers-gateway.internal --port 8443
```

`--no-register` starts the service without registering.

## 6. Where it runs, and HTTPS

PacketFence reaches a plugin over plain HTTP **only on the loopback of
api-frontend** (`127.0.0.0/8`, `::1`, `localhost`). Anywhere else it uses HTTPS
and verifies the certificate.

| Deployment | Host to register | Transport |
|---|---|---|
| Kubernetes, the plugin is a container of the api-frontend pod | `127.0.0.1` | HTTP |
| Kubernetes, the plugin has its own Service | the Service name, eg `notes-go.packetfence.svc` | HTTPS, certificate for that name |
| systemd host: api-frontend runs in a container, the plugin on the host | `containers-gateway.internal` (the host, as the containers see it) | HTTPS, certificate for `containers-gateway.internal` |
| another server | its name | HTTPS, certificate for that name |

On a systemd host the plugin must listen on an address the containers reach,
eg `0.0.0.0:8443` with the port open to the container network only.

The certificate must chain to a system authority, or to the authorities in
`/usr/local/pf/conf/ssl/ui_plugins_ca.pem` (PEM, optional, read by
api-frontend). A CA of your own, eg:

```
# once: a CA for the plugins, trusted by api-frontend
openssl req -x509 -newkey rsa:3072 -nodes -days 3650 -subj "/CN=PacketFence UI plugins CA" \
  -keyout ui_plugins_ca.key -out /usr/local/pf/conf/ssl/ui_plugins_ca.pem

# per plugin: a certificate for the host PacketFence reaches it at
openssl req -newkey rsa:3072 -nodes -subj "/CN=containers-gateway.internal" -keyout notes.key -out notes.csr
openssl x509 -req -in notes.csr -CA /usr/local/pf/conf/ssl/ui_plugins_ca.pem -CAkey ui_plugins_ca.key \
  -CAcreateserial -days 825 -out notes.crt \
  -extfile <(printf "subjectAltName=DNS:containers-gateway.internal\nextendedKeyUsage=serverAuth")
```

Keep the CA key off the PacketFence server, and restart api-frontend after
changing `ui_plugins_ca.pem`.

## 7. Running it as a service

**systemd**, eg `/etc/systemd/system/notes-go.service`:

```ini
[Unit]
Description=PacketFence admin UI plugin notes-go
After=packetfence-pfconfig.service packetfence-api-frontend.service
Wants=packetfence-pfconfig.service

[Service]
ExecStart=/usr/local/pf/plugins/notes-go/notes-go -listen 0.0.0.0:8443 -host containers-gateway.internal -port 8443 -tls-cert /usr/local/pf/plugins/notes-go/notes.crt -tls-key /usr/local/pf/plugins/notes-go/notes.key
# SIGTERM: the plugin deregisters itself
KillSignal=SIGTERM
TimeoutStopSec=15
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

For the Perl plugin, `ExecStart=/usr/local/pf/plugins/notes-perl/plugin.pl
--listen 'https://0.0.0.0:8444?cert=…&key=…' --host containers-gateway.internal --port 8444`.

**Kubernetes:** run the plugin as a container of the api-frontend pod
(loopback, plain HTTP), or as a Deployment with a Service and a certificate
for the Service name. The container needs what the accessors use: pfconfig
(`PFCONFIG_TCP_HOST`, `PFCONFIG_TCP_PORT`) and the system init key for Go, the
PacketFence tree for Perl. Give the pod a `terminationGracePeriodSeconds` long
enough to deregister. A plugin killed without deregistering stays registered:
its pages answer 502 and it drops out of the menus within about 30s.

## 8. Testing it

With an admin token (`POST /api/v1/login`):

```
TOKEN=…
API=https://<packetfence>:1443/api/v1
curl -sk -H "Authorization: Bearer $TOKEN" $API/plugins | jq '[.items[].id]'
curl -sk -H "Authorization: Bearer $TOKEN" $API/plugin/notes-go/notes
curl -sk -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -X POST $API/plugin/notes-go/notes -d '{"id":"first","text":"hello"}'
```

Then open Configuration → Integration → "Notes (go plugin)" in the admin UI.
`register.pl list` shows the registrations.

### Troubleshooting

| Symptom | Where to look |
|---|---|
| The plugin is not in `GET /api/v1/plugins` | api-frontend logs `UI plugin "<name>" ignored: …` with the reason (manifest refused, fetch failed, certificate not trusted). An admin without the `menu.can` does not get it either |
| 403 `… is not an API method of the manifest` | the path or the verb is not a method of the manifest (eg `PUT` instead of `PATCH`, a path with two segments for `{id}`) |
| 403 `… do not satisfy …can` | the admin lacks the roles of the `can` |
| 502 `The plugin "<name>" is unavailable` | the service does not answer, its certificate is not trusted, or it answered something else than JSON, a redirect, a 401/407, or more than 10 MB (api-frontend logs which) |
| The page shows but a field is missing | the `can` of the field or its tab, or its `when` |
