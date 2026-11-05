# Admin UI plugins

A plugin adds a page to the admin UI without rebuilding it. The page is
described by a JSON **manifest** that the plugin serves over HTTP, and core
renders it with its own views and components. **A plugin never ships code to
the UI**: it can only use the templates, components and validators core
already provides, listed in
[`html/pfappserver/root/src/plugins/catalog.json`](../../html/pfappserver/root/src/plugins/catalog.json).

This works the same on a systemd host and on Kubernetes: only redis-cache,
pfconfig and HTTP are involved.

## How it works

```
plugin service starts
  HSET pf:ui_plugins <id> '{"id":…,"scheme":"http","host":…,"port":…,"manifest_path":…}'   (redis-cache)
  expire resource::ui_plugins                                                              (pfconfig)

admin logs in
  GET /api/v1/ui_plugins            api-frontend, existing Go "api" handler
    reads resource::ui_plugins      pfconfig namespace built from the redis hash
    fetches each manifest           3s timeout, cached 30s (5s for a failure)
    validates it against the catalog, leaves out (and logs) unreachable or invalid ones
  the UI adds the routes and sidebar items of each plugin

plugin service stops
  HDEL pf:ui_plugins <id>
  expire resource::ui_plugins
```

A plugin that stops without deregistering (crash, killed pod) disappears from
the UI as soon as its manifest cannot be fetched: its registration stays in
redis until it registers again.

`GET /api/v1/ui_plugins` is allowed to any admin. The sidebar item and the
routes of a plugin are only shown to the admins allowed by its `menu.can`.

## Registration

The registration tells core where the manifest is:

| Property | |
|---|---|
| `id` | `^[a-z][a-z0-9_-]{0,62}$`, the field of the hash, also the `id` of the manifest |
| `scheme` | `http` (default) or `https` |
| `host`, `port` | how **core** reaches the plugin service (eg: its Kubernetes Service name, or `containers-gateway.internal` and a published port) |
| `manifest_path` | the path of the manifest, eg: `/pf-ui/manifest.json` |

Register when the service is ready to serve its manifest, deregister when it
stops:

- shell: [`examples/register.sh`](examples/register.sh) (`redis-cli` and bash),
  for a Kubernetes `postStart`/`preStop` hook, a systemd
  `ExecStartPost`/`ExecStopPost` or a container entrypoint
- Go: `github.com/inverse-inc/packetfence/go/uiplugins`,
  `uiplugins.NewRegistry().Register(ctx, uiplugins.Registration{…})` and
  `Deregister(ctx, id)`

Both use the environment of the PacketFence services: `REDIS_CACHE_HOST`,
`REDIS_CACHE_PORT`, `PFCONFIG_TCP_HOST`, `PFCONFIG_TCP_PORT`.

**Kubernetes with several pfconfig pods (not verified):** an expire sent to
the pfconfig Service reaches one pod only, the others keep the previous list
until their namespace is rebuilt. `pfconfig::git_storage::k8s_deploy` expires
every pod of the deployment for configuration changes, the registration
helpers do not do that yet.

## Manifest

The manifest follows the JSON Schema
[`manifest.schema.json`](manifest.schema.json) (generated from the catalog).
The API also checks that every validator applies to the type of its component,
that `when` names another field, and that the `api` paths have an `{id}` where
needed.

| Property | |
|---|---|
| `manifestVersion` | `1` |
| `id` | the registered id |
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
| `can` | the ACL needed to see the page, `<verb> <target>` (eg: `read syslog` for `SYSLOG_READ`) |

The page is at `/<area>/plugins/<id>` (and `/new`, `/<item id>`,
`/<item id>/clone` for a collection).

### API

The same mapping as the `_api.js` of the core views: a path relative to
`/api/v1` by method, called with a fixed verb. `{id}` is the id of the item.

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

A collection needs `list` or `search`. A missing method is not offered:
without `create` there is no "New" or "Clone", without `update` nothing can be
saved, without `delete` nothing can be deleted. The `OPTIONS` answers give the
form its meta (allowed values, placeholders, defaults, required fields) like
for the core views.

The paths go through the api-frontend like any API call of the UI: an
existing core API, or an API the plugin exposes there (not part of this
change).

### Form fields

| Property | |
|---|---|
| `namespace` | the property of the item, dots for nested ones (`a.b`) |
| `component` | a core component of the catalog, eg: `BaseFormGroupInput`, `BaseFormGroupChosenOne`, `BaseFormGroupSwitch` |
| `label`, `text`, `placeholder` | translatable texts |
| `props` | other properties of the component (eg: `options`, `enabledValue`) |
| `when` | show the field only when another one `equals`, `notEquals` or is `in` a value |
| `validators` | `[{ "fn": "isPort" }, { "fn": "min", "args": [2], "message": { "en": "…" } }]`, the core validators of the catalog |

## Examples

- [`examples/syslog-forwarders`](examples/syslog-forwarders/manifest.json): a
  collection mapped to the core syslog forwarders API
- [`examples/alerting`](examples/alerting/manifest.json): a resource with
  tabs, mapped to the core alerting settings

To try one, serve its directory and register it, eg:

```
cd docs/ui-plugins/examples/syslog-forwarders
python3 -m http.server 8099 &
../register.sh register syslog-forwarders <address core reaches> 8099 /manifest.json
```

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
