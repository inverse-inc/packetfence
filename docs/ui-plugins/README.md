# Admin UI plugins

A plugin adds a page to the admin UI without rebuilding it. The page is
described by a JSON **manifest** that the plugin serves over HTTP, and core
renders it with its own views and components. **A plugin never ships code to
the UI**: it can only use the templates, components and validators core
already provides, listed in
[`html/pfappserver/root/src/plugins/catalog.json`](../../html/pfappserver/root/src/plugins/catalog.json).

This works the same on a systemd host and on Kubernetes: only the
PacketFence database (the `chi_cache` table) and HTTP are involved.

## How it works

```
plugin service starts, serves <scheme>://<host>:<port>/manifest.json (https unless on the loopback)
  registers: the row ui_plugins::<name> of chi_cache       (Go or Perl accessor)

admin logs in
  GET /api/v1/plugins               api-frontend, existing Go "api" handler
    reads the registrations         chi_cache, at most every 5s
    fetches each manifest           3s timeout, then refreshed in the background (30s, 5s for a failure)
    validates it against the catalog, leaves out (and logs) unreachable or invalid ones
  the UI adds the routes and sidebar items of each plugin

admin uses a plugin page
  * /api/v1/plugin/<name>/<path>    api-frontend, existing Go "api" handler
    checks the can of the manifest  (see ACL)
    proxies the declared API to <scheme>://<host>:<port>/<path>, JSON answers only

plugin service stops
  deregisters: the row is deleted                         (Go or Perl accessor)
```

A manifest is fetched once when its plugin is first listed. After that the
last result is answered at once and refreshed in the background, so a slow or
dead plugin does not slow down the admin UI. A plugin that stops without
deregistering (crash, killed pod) stays registered: it disappears from the UI
once a refresh of its manifest fails, within about 30s, and its pages answer
502 ("The plugin … is unavailable") meanwhile. It is listed again as soon as
its manifest answers, or when it registers again.

The registrations are rows of the database: they survive a restart of any
service and every api-frontend reads the same ones, whatever the number of
pods.

`GET /api/v1/plugins` and `/api/v1/plugin/` are allowed to any admin by
api-aaa. What each admin sees and may call is decided by the `can` of the
manifest, see [ACL](#acl).

## Registering a plugin

A plugin registers itself when its service serves its manifest, and
deregisters itself when it stops, with the PacketFence accessors in Go or in
Perl. Both write the same row and apply the same rules, so a plugin can use
either. They use the PacketFence database through the PacketFence
configuration: **the plugin never handles the database credentials**.

| Operation | Go (`github.com/inverse-inc/packetfence/go/uiplugins`) | Perl (`pf::ui_plugins`) |
|---|---|---|
| register or update itself | `uiplugins.Register(ctx, uiplugins.Registration{Name, Host, Port}) error` | `pf::ui_plugins::register({ name => …, host => …, port => … })` → `($status, $error)` |
| deregister itself | `uiplugins.Deregister(ctx, name) error` | `pf::ui_plugins::deregister($name)` → `($status, $error)` |
| get one | `uiplugins.Get(ctx, name) (*Registration, error)`, nil when not registered | `pf::ui_plugins::get($name)` → hashref, undef when not registered |
| list all | `uiplugins.List(ctx) (map[string]Registration, error)` | `pf::ui_plugins::list()` → hashref name → registration |
| validate without writing | `Registration.Validate() error` | `pf::ui_plugins::validate($registration)` → `($ok, $error)` |

| Property | |
|---|---|
| `name` | `^[a-z][a-z0-9_-]{0,62}$`, also the `id` of the manifest and the `<name>` of `/api/v1/plugin/<name>/` |
| `host` | a hostname or an IP address **core** reaches the plugin service at (eg: its Kubernetes Service name, or `containers-gateway.internal`). Plain HTTP on the loopback only, HTTPS with a certificate valid for this host otherwise, see [The API of a plugin](#the-api-of-a-plugin) |
| `port` | 1 to 65535 |

Register is an upsert: registering again updates the registration.
Deregistering a plugin that is not registered is not an error. The Go
functions `RegisterDB`, `DeregisterDB`, `GetDB` and `ListDB` do the same with
a `*sql.DB` of your own.

The row, for reference: key `ui_plugins::<name>`, value
`{"name":…,"host":…,"port":…}`, `expires_at` NULL (pfcron's
`cleanup_chi_database_cache` never removes it).

Examples:

- Go: [`examples/register.go`](examples/register.go), registers, waits for
  SIGTERM or SIGINT, deregisters
- Perl: [`examples/register.pl`](examples/register.pl)
  `register <name> <host> <port>`, `deregister <name>`, `list`, eg for a
  systemd `ExecStartPost`/`ExecStopPost` or a Kubernetes `postStart`/`preStop`
  hook

## The API of a plugin

The plugin serves its manifest at `/manifest.json` and the API of its page.
The admin UI reaches that API through api-frontend only:
`/api/v1/plugin/<name>/<path>` is passed to `<scheme>://<host>:<port>/<path>`,
with the query string and the body.

**Transport.** A plugin on the loopback of api-frontend (`127.0.0.0/8`,
`::1`, `localhost`: the same host or pod) is reached over plain HTTP. Any
other host is reached over **HTTPS**: its certificate must be valid for the
registered host and chain to the system authorities or to
`/usr/local/pf/conf/ssl/ui_plugins_ca.pem` (optional, PEM). Redirects are not
followed and the proxy settings of the environment are not used.

**What is passed.** Only the API methods the manifest declares: the path must
match one of its `api` paths (`{id}` is one segment, never empty, `.` or
`..`) with the verb of that method (`list`/`item`: GET or HEAD,
`listOptions`/`itemOptions`: OPTIONS, `search`/`create`: POST, `update`:
PATCH, `delete`: DELETE). Anything else is refused (403), and so is a call
the admin is not allowed (see [ACL](#acl)).

- the admin token is not passed (`Authorization`, `Cookie` are removed), the
  plugin gets the admin api-aaa checked instead:
  - `X-PacketFence-Username`
  - `X-PacketFence-Admin-Roles`: the admin roles (eg: `ALL`)
  - `X-PacketFence-Admin-Actions`: their actions on the targets the `can`s of
    the manifest name (eg: `SYSLOG_READ,SYSLOG_UPDATE` for a manifest about
    `syslog`)

  No other `X-PacketFence-*` header reaches the plugin, whatever its spelling
  (`_` for `-`, case).
- a request body is limited to 10 MB, a call to 60s

**What is answered.** The answer must be JSON (`application/json` or
`+json`, valid, at most 10 MB) or empty. It is passed with fixed headers
(`Content-Type: application/json`, `X-Content-Type-Options: nosniff`, a
sandboxing `Content-Security-Policy`, `Cache-Control: no-store`): the
headers of the plugin (cookies, CORS, …) are not. A redirect, a 401 or 407,
anything else than JSON, a plugin whose manifest is unavailable or that does
not answer is a 502.

The answers follow the PacketFence API, as the core views expect them: `{
"items": [...], "nextCursor": … }` for a list or a search, `{ "item": {...} }`
for an item, `{ "meta": {...} }` for `OPTIONS`, `{ "message": "…" }` for a
write or an error. The UI shows the `message`, `warnings[].message` and
`errors[].message` of a plugin as text (escaped), and ignores the `pattern`s
of its `OPTIONS` meta (regular expressions the browser would run): use a
`matches` validator of the manifest instead.

## Manifest

The manifest follows the JSON Schema
[`manifest.schema.json`](manifest.schema.json) (generated from the catalog).
The API also checks that every validator applies to the type of its component,
that `when` names another field, and that the `api` paths have an `{id}` where
needed.

| Property | |
|---|---|
| `manifestVersion` | `1` |
| `id` | the registered name |
| `title`, `description` | translatable texts: `{ "en": "…", "fr": "…" }`, `en` is required |
| `menu` | where the page goes, see below |
| `template` | `resource` (one object, eg: a settings page) or `collection` (a list, and items to create, edit, clone, delete) |
| `api` | the API of the page, see below |
| `collection` | `collection` template only: `columns` (`key`, `label`, `sortable`) and `searchFields` |
| `form` | `fields`, or `tabs` (`title`, `fields`) |

### Menu

| Property | |
|---|---|
| `area` | `configuration`, `status`, `auditing`, `nodes`, `users` or `preferences` |
| `section` | the path of an existing sidebar section, at any depth (eg: `/configuration/integration`). Without it the page is a new top-level section |
| `group` | the untranslated name of a group of `section` (eg: `Main Configuration`) |
| `before`, `after` | the path of a sibling item |
| `icon` | a vue-awesome icon core already uses, for a new section |
| `can` | **required**: the ACL needed to see the item, open the pages and call the plugin, see [ACL](#acl) |

The page is at `/<area>/plugins/<id>` (and `/new`, `/<item id>`,
`/<item id>/clone` for a collection).

### API

The same mapping as the `_api.js` of the core views: a path relative to the
plugin, `/api/v1/plugin/<name>/`, by method, called with a fixed verb. `{id}`
is the id of the item. A manifest cannot reach a core API.

| Method | Verb | `collection` | `resource` |
|---|---|---|---|
| `list` | GET | path | |
| `listOptions` | OPTIONS | path | |
| `search` | POST | path | |
| `create` | POST | path | |
| `item` | GET | path with `{id}`, **required** | path, **required** |
| `itemOptions` | OPTIONS | path with `{id}` | path |
| `update` | PATCH | path with `{id}` | path |
| `delete` | DELETE | path with `{id}` | |

`create`, `update` and `delete` are `{ "path": "…", "can": … }`: the `can`
is required, the method is only offered to the admins it allows, and the API
refuses the call to the others (see [ACL](#acl)). A path has one `{id}` at
most, and `search` cannot have the path of `create`.

A collection needs `list` or `search`. A missing method is not offered:
without `create` there is no "New" or "Clone", without `update` nothing can be
saved, without `delete` nothing can be deleted. The `OPTIONS` answers give the
form its meta (allowed values, placeholders, defaults, required fields) like
for the core views.

The `OPTIONS` answers are the plugin's too: an empty `{ "meta": {} }` is
fine.

### Form fields

| Property | |
|---|---|
| `namespace` | the property of the item, dots for nested ones (`a.b`); not `__proto__`, `constructor` or `prototype` |
| `component` | a core component of the catalog, eg: `BaseFormGroupInput`, `BaseFormGroupChosenOne`, `BaseFormGroupSwitch` |
| `label`, `text`, `placeholder` | translatable texts |
| `props` | other properties of the component (eg: `options`, `enabledValue`). Not the ones set from the field properties or rendered as HTML (`forbiddenProps` of the catalog) |
| `when` | show the field only when another one `equals`, `notEquals` or is `in` a value |
| `can` | show the field only to the admins allowed, see [ACL](#acl) |
| `validators` | `[{ "fn": "isPort" }, { "fn": "min", "args": [2], "message": { "en": "…" } }]`, the core validators of the catalog. A `matches` regular expression has at most 256 characters and no nested quantifiers (`(a+)+`) |

A tab (`tabs[]`) can also have a `can`: it is only shown to the admins
allowed.

The texts of a manifest are shown as text: the markup of a `text` or a
validator `message` is escaped, a plugin cannot add HTML to the UI.

### ACL

A `can` is the JSON form of the `acl.$can`, `acl.$some` and `acl.$every` of
the core views, checked against the admin roles of the admin:

| `can` | |
|---|---|
| `"read syslog"` | `<verb> <target>`: the admin role `SYSLOG_READ` |
| `{ "some": ["read syslog", "read system"] }` | any of them |
| `{ "every": ["read syslog", "update syslog"] }` | all of them |

`some` and `every` take `can`s, nested 3 levels at most. The verbs are the
actions of the admin roles (`read`, `create`, `update`, `delete`,
`create-multiple`, …, `acl.verbs` of the catalog, `_` replaced by `-`), the
target is the rest of the role, lowercase (`CONFIGURATION_MAIN_READ` is
`read configuration_main`).

| Where | Without the ACL |
|---|---|
| `menu.can` | no sidebar item, the routes of the plugin are refused (as the `meta.can` of a core route) |
| `api.create.can` | no New and no Clone, the routes are refused |
| `api.update.can` | no Save |
| `api.delete.can` | no Delete |
| a field or tab `can` | not shown |

The API checks the same `can`s for every call to the plugin: `menu.can` for
any request, and the `can` of `api.create`, `api.update` or `api.delete` for
those calls. `GET /api/v1/plugins` only lists the plugins whose `menu.can`
the admin satisfies. The `can` of a field or a tab only shapes the form: the
plugin checks its own rules with `X-PacketFence-Admin-Actions` if it needs to.

## Examples

[`examples/server.py`](examples/server.py) is an example plugin service,
Python standard library only: it serves the manifest of a directory and the
API of its page from memory (and `meta.json`, `data.json` when present).

- [`examples/hello`](examples/hello/manifest.json): a collection, with
  `can`s on the menu, the write methods and a field, `when`, validators and
  `OPTIONS` meta
- [`examples/hello-settings`](examples/hello-settings/manifest.json): a
  resource with tabs

To try one on the host of api-frontend (loopback, plain HTTP):

```
docs/ui-plugins/examples/server.py docs/ui-plugins/examples/hello --host 127.0.0.1 --port 8090 &
docs/ui-plugins/examples/register.pl register hello 127.0.0.1 8090
```

From another host, serve HTTPS with a certificate valid for the registered
host (`--tls-cert`, `--tls-key`).

and `register.pl deregister hello` when you stop it.

## Catalog

`html/pfappserver/root/src/plugins/catalog.json` is the only list of what a
manifest may use. After changing it:

```
node html/pfappserver/root/build/ui-plugins-catalog.js
```

regenerates `go/uiplugins/catalog.json` (embedded in the API) and
`docs/ui-plugins/manifest.schema.json`, and checks that
`src/plugins/registry.js` has a loader for every component and a builder for
every validator. Every component of the catalog is referenced by a lazy loader
in the registry, so it is always in the build, even if no core view used it
anymore (today they all are in the initial `app` chunk already, through the
core views).
