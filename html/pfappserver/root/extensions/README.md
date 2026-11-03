# Admin UI extensions

An extension adds routes, sidebar and navbar items, store modules (Vuex and
Pinia), API modules, components, translations and API specifications to the
admin UI. Extensions are kept out of this repository, usually in private
repositories, and are compiled into the UI when they are present at build time.

With no extension present, the UI builds exactly as it does without this
mechanism.

A complete example, built only on demand, is in
[`../extensions.example/hello-world`](../extensions.example/hello-world).

## Adding extensions to a build

Extensions are found in two places:

1. **Drop-ins.** Each directory in `html/pfappserver/root/extensions/` is an
   extension (this directory, gitignored except for this README). Clone the
   extension repositories here:

   ```bash
   git clone <private repository> html/pfappserver/root/extensions/acme
   ```

   Names starting with `.` or `_` are skipped. Drop-ins are built in name
   order.
2. **`PF_UI_EXTENSIONS`.** A `:` separated list of absolute paths, built after
   the drop-ins in the given order. Use it during development:

   ```bash
   PF_UI_EXTENSIONS=/src/acme:/src/other npm run serve
   ```

`node build/ui-extensions.js --list` shows what was found. The build logs
`[pf-ui-extensions] building with: ...` when it compiles extensions.

The id of an extension is its directory name. It must match
`^[a-z0-9][a-z0-9-]*$` and be unique.

The build fails with a clear message when:

- an id is invalid or used twice
- `index.js` is missing
- `apiVersion` is missing or not supported
- the extension has its own `node_modules` directory (that would load a second
  copy of Vue or Vuex), or is itself inside a `node_modules` directory
- its `package.json` lists npm packages that core doesn't provide
- a `PF_UI_EXTENSIONS` entry is relative or doesn't exist

**Restart `npm run serve` after adding or removing an extension.** Changes
inside an existing extension are reloaded as usual.

### Builds, packages and images

Every build of the UI must see the same extensions, or the packages and the
images will ship different UIs. Today there are two builds:

- `.build_artifacts_doc_job` in `.gitlab-ci.yml`, whose `dist/` the rpm and
  deb packages ship
- `containers/httpd.admin_dispatcher/Dockerfile`, which copies `html/` and runs
  `make vendor light-dist`

Clone the extensions, don't symlink them: a symlink isn't followed into the
Docker build context.

The packaging never ships an extension's source, only the compiled `dist/`.
This covers `config.mk`, `debian/rules`, `rpm/packetfence.spec` and
`.dockerignore`.

## Layout

```
acme/
  index.js              required, the definition (below)
  components/ store/ …  free layout
  i18n/en.po            translations, see Translations
  i18n/fr.po
  docs/api/spec/static/ API specification, see API specification
    paths/…yaml
    components/<type>/…yaml
  package.json          optional, only to declare the dependencies used (must be provided by core)
```

## Definition (`index.js`)

```js
export default {
  apiVersion: 1,      // required, a literal: checked at build time

  routes: [ ... ],    // vue-router 3 records
  sidebar: { ... },   // sidebar items, per area
  navbar: [ ... ],    // top navbar items
  storeModules: { },  // global Vuex modules
  install (Vue, { router, store, i18n, pinia }) { }  // global components, directives, plugins...
}
```

Every key other than `apiVersion` is optional.

### Routes

Routes are added anywhere in the core route tree, not only as new top-level
views:

```js
routes: [
  // a child of an existing route, `parent` is a route name or an absolute path, at any depth
  { parent: 'configuration', path: 'acme', name: 'acme', component: TheView, beforeEnter },
  { parent: '/configuration', path: 'pki/acme', name: 'acmePki', component: TheView },
  { parent: 'status', path: 'acme', name: 'statusAcme', component: TheView, meta: { can: 'read system' } },
  // the same name or path as an existing sibling: replaces it
  { parent: 'configuration', path: 'kafka', name: 'kafka', component: AcmeKafka },
  // without parent: a new top-level view, the path must be absolute
  { path: '/acme', name: 'acmeView', component: TheView, meta: { can: () => acl.$can('read', 'system') }, children: [ ... ] }
]
```

- The areas are the routes named `status`, `reports`, `auditing`, `nodes`,
  `users`, `configuration` and `preferences`.
- An unknown parent is logged in the console and the route is ignored.
- Extensions are applied in order, so a later extension overrides an earlier
  one. Every extension route gets `meta.extension` set to its id.
- `meta.can` is a function or a `'verb target'` string, as in core. The
  children of `configuration` inherit its `read configuration_main` check.
- A top-level view is only shown in the navbar if its route's `meta.can`
  allows it.
- Load views lazily:
  `() => import(/* webpackChunkName: "ext-acme" */ './components/TheView')`.

### Sidebar

Contributions are given per area, keyed by the area's route name. Use a
function so the names are translated again when the language changes:

```js
sidebar: {
  configuration: ({ i18n }) => ([
    // into an existing section (its path, at any depth), after an existing item
    { parent: '/configuration/integration', after: '/configuration/firewalls',
      item: { name: i18n.t('Acme'), path: '/configuration/acme', saveSearchNamespace: 'acme' } },
    // into an existing group of a section; the group is matched by its untranslated name
    { parent: '/configuration/integration', group: 'PKI',
      item: { name: i18n.t('Acme CA'), path: '/configuration/pki/acme' } },
    // the same path as an existing item, anywhere: replaces it
    { item: { name: i18n.t('Kafka'), path: '/configuration/kafka' } },
    // without parent: a new top-level section, `before`/`after` an existing one or appended
    { before: '/configuration/system_configuration',
      item: { name: i18n.t('Acme'), path: '/configuration/acme_section', icon: 'flask', collapsable: true, items: [ ... ] } }
  ]),
  status: ({ i18n }) => ([
    { item: { name: i18n.t('Acme'), path: '/status/acme', can: 'read system' } }
  ])
}
```

- Items use the core shape: `{ name, path, can, class, saveSearchNamespace }`
  for a link, and `{ name, path, icon, collapsable, items }` for a section.
- `can` is a `'verb target'` string or a function.
- Sections are matched by path. Each section's path needs a route, which is its
  landing page.
- An unknown section or group is logged in the console and the item is
  ignored. An unknown `before`/`after` appends the item.
- The Configuration sidebar also feeds the quick links of Status / About.

### Navbar

```js
navbar: [ { name: 'Acme', to: '/acme', activePrefix: '/acme', can: 'read system' } ]
```

- `name` is translated with `$t`.
- Without `can`, visibility comes from the `meta.can` of the top-level route
  `to`.

### Store modules

- **Global Vuex modules** go in `storeModules: { acme: module }`. They are
  registered once at startup and must be `namespaced: true`.
  - They must implement a `$RESET` mutation, which `store.reset()` commits on
    logout.
  - A name already used by core or by another extension is logged and ignored.
    Core modules can't be replaced.
  - `$_` names are refused here, because `$_` modules are unregistered on
    logout.
- **Temporary Vuex modules** follow the core pattern: register them lazily in a
  route `beforeEnter`, named `$_<id>_...`:

  ```js
  const beforeEnter = (to, from, next = () => {}) => {
    if (!store.state.$_acme)
      store.registerModule('$_acme', AcmeStore)
    next()
  }
  ```
- **Pinia stores** need no registration. Use
  `defineStore({ id: '$_<id>_...' })` or `makeSearch('<id>...')` from
  `@/store/factory/search`. Prefix the ids with the extension id.

### API modules and components

- Import core with `@/...`, for example `import apiCall from '@/utils/api'`,
  `@/components/new`, `@/views/Configuration/_components/new` or
  `@/store/factory/search`.
- Import other files of the extension with relative paths, or with
  `@pf-ext/<id>/...`.
- Use `@/router`, `@/store` and `@/utils/acl` **only inside functions**
  (`beforeEnter`, `meta.can`, actions, `setup`), never at the top level of a
  module. The extension is evaluated while the router is being built, so these
  modules aren't ready yet. Core modules follow the same rule.
- Import the icons you use: `import 'vue-awesome/icons/flask'`.
- Only the npm packages of core `package.json` are available. An extension
  that needs another package needs a core change to add it first.
- SFC styles get the same SCSS variables and mixins as core.
- Extensions in the drop-in directory are linted with the core ESLint rules
  during the build, and a lint error fails it. Symlinked extensions and the
  ones outside of `html/pfappserver/root` aren't linted, so lint them in their
  repository. `npm run lint` uses `--fix`, which also rewrites files of the
  drop-ins.

New ACL targets (`ACME_READ`, ...) need no UI change. The admin roles come
from the server and `setupAcl` parses any `<TARGET>_<ACTION>`. The backend must
define them.

## Translations

The admin UI uses English strings as keys (`$t('...')`, `v-t`, `i18n.t('...')`).
The core strings are extracted to `conf/I18N/api/en.po`, the `api` resource of
the public Transifex project. Extensions keep their own PO files and their own
Transifex resource in their repository, so private strings never reach the
public project.

1. **Extract** the strings of the extensions, from the root of the packetfence
   repository:

   ```bash
   ./addons/extract_i18n_strings_ui_extensions.sh
   ```

   For each extension this writes `<extension>/i18n/en.po.tmp`, which runs
   `addons/extract_i18n_strings_api.pl --src <extension> --po <extension>/i18n/en.po`.
   Strings core already has (`Save`, `Cancel`, ...) are skipped, because the
   core lexicon translates them. `addons/update_translations.sh` runs it too.
2. **Push and pull** with the extension's own `.tx/config`:

   ```ini
   [main]
   host = https://www.transifex.com

   [o:<organization>:p:<private project>:r:<extension id>]
   file_filter = i18n/<lang>.po
   source_file = i18n/en.po
   source_lang = en
   type        = PO
   ```
3. **Build.** `i18n/<lang>.po` is compiled into the UI, one lazily loaded chunk
   per language (`ext-i18n-<lang>`). The translations are merged after the core
   lexicon of the language is loaded from the API. Languages are named like
   core's (`fr`, `tr`, ...).

## API specification

Extensions document their endpoints with static OpenAPI files, in the same
layout as the core `docs/api/spec/static`:

```
<extension>/docs/api/spec/static/paths/acme.yaml
<extension>/docs/api/spec/static/components/schemas/Acme.yaml
```

`docs/api/spec/generate-openapi-spec.pl` merges them after the core static
specification, but only when asked to (`--with-extensions` or
`PF_API_SPEC_EXTENSIONS=1`). `openapi.json` and `openapi.yaml` are committed
in the public repository. Never commit a specification generated with
extensions: `git-unstage-generated.sh` restores them.

- A path or component with the same name as a core one replaces it, with a
  warning.
- Paths added by an extension are marked with `x-pf-extension: <id>`.

## Limits

- Extensions add or replace whole routes and sidebar items. They can't add part
  of an existing view (a tab, a column, a dashboard widget, a form field). To
  change a core view, replace its route.
- The section landing pages of Configuration list the core items only.
- There are no keyboard shortcuts for the navbar items of extensions.
- Extensions use core internals (`@/...`). Pin an extension branch to each
  PacketFence release. `apiVersion` only covers the definition above.
