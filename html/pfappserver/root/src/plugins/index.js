/**
 * Admin UI plugins (see the Developers Guide, "Admin UI plugins").
 *
 * Plugin services register in the database (go/uiplugins, pf::ui_plugins), the
 * API lists the ones whose manifest is valid (GET /api/v1/plugins) and proxies
 * /api/v1/plugin/<id>/<path> to them. Once logged in, the routes and sidebar items
 * of their manifests are added and their pages are built from the manifests
 * with the core components only (registry.js).
 *
 * Without any plugin, nothing is added.
 *
 * Do not import '@/router' or '@/store' here: this module is imported while the
 * router is being built.
 */
import Vue from 'vue'
import Router from 'vue-router'
import apiCall from '@/utils/api'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { types, validators } from './registry'
import catalog from './catalog.json'
import { can as canAcl } from './acl'
import Icon from 'vue-awesome/components/Icon'

const PREFIX = '[pf-ui-plugins]'

/* eslint-disable no-console */
const logError = (...args) => console.error(PREFIX, ...args)
const logWarning = (...args) => console.warn(PREFIX, ...args)
/* eslint-enable no-console */

const state = Vue.observable({
  plugins: [] // [{ id, manifest }], frozen
})

/**
 * Translatable texts: { en: '...', fr: '...' }
 */
export const translate = (text, locale = i18n.locale) => {
  if (!text)
    return undefined
  if (typeof text === 'string')
    return text
  const [ base ] = `${locale}`.split(/[-_]/)
  return text[locale] || text[base] || text.en
}

// the manifest texts the core components render with v-html (the text of a
// field, the validator messages): a plugin cannot add markup to the UI
export const escapeHtml = s => ((s === undefined || s === null) ? s : `${s}`.replace(/[&<>"']/g, c => `&#${c.charCodeAt(0)};`))

/**
 * Routes
 */
export const pluginPath = ({ id, manifest: { menu: { area } } }) => `/${area}/plugins/${id}`

export const pluginRouteNames = ({ id }) => ({
  collection: `plugin-${id}`, // or the resource
  new: `plugin-${id}-new`,
  item: `plugin-${id}-item`,
  clone: `plugin-${id}-clone`
})

// the names of the plugin routes added to the router
const addedRoutes = new Set()

// remove the plugin routes: the matcher of the router is built again from its
// own routes (vue-router 3 cannot remove a route). An abstract router does not
// touch the location. This drops every route added at run time with
// addRoute, not only the plugin ones: nothing else in core adds routes; if
// something does one day, it must add them again after a plugin load.
const removeRoutes = router => {
  if (addedRoutes.size === 0)
    return
  router.matcher = new Router({ ...router.options, mode: 'abstract' }).matcher
  addedRoutes.clear()
}

// The views of a plugin: its own components, extending the shared ones. The
// router-views of the areas have no key, a component shared by two plugins
// would be reused, with the setup of the first plugin, when the admin goes
// from the page of one to the page of the other.
const ownViews = (id, views) => Object.entries(views).reduce((own, [ kind, view ]) => {
  let loaded
  own[kind] = () => {
    // a failed load is not kept: the next navigation loads the chunk again
    loaded = loaded || Promise.resolve(view())
      .then(m => ({ extends: m.default || m, name: `plugin-${id}-${kind}` }))
      .catch(err => {
        loaded = undefined
        throw err
      })
    return loaded
  }
  return own
}, {})

// the routes of a plugin, the same as the _router.js of a core view
const pluginRoutes = (plugin, shared) => {
  const { id, manifest: { template, api = {}, bundle, menu: { can } } } = plugin
  const views = ownViews(id, shared)
  const names = pluginRouteNames(plugin)
  const path = `plugins/${id}`
  // vue-browser-acl checks meta.can on every navigation (string or function)
  const meta = { plugin: id, ...((can) ? { can: () => canAcl(can) } : {}) }
  if (template === 'bundle') // its own code, at the "page" mount
    return (hasMount(bundle, 'page'))
      ? [{ path, name: names.collection, component: views.bundle, props: () => ({ pluginId: id, kind: 'page' }), meta }]
      : []
  const createCan = api.create && api.create.can
  const metaCreate = (createCan) ? { ...meta, can: () => canAcl(can) && canAcl(createCan) } : meta
  if (template === 'resource')
    return [{ path, name: names.collection, component: views.resource, props: () => ({ pluginId: id }), meta }]
  return [
    { path, name: names.collection, component: views.search, props: () => ({ pluginId: id }), meta },
    ...((api.create)
      ? [
        { path: `${path}/new`, name: names.new, component: views.item, props: () => ({ pluginId: id, isNew: true }), meta: metaCreate },
        { path: `${path}/:id/clone`, name: names.clone, component: views.item, props: route => ({ pluginId: id, id: route.params.id, isClone: true }), meta: metaCreate }
      ]
      : []
    ),
    { path: `${path}/:id`, name: names.item, component: views.item, props: route => ({ pluginId: id, id: route.params.id }), meta }
  ]
}

// the routes of the plugins replace the ones of the last load: a manifest may
// have changed its area, template or api, or a plugin may be gone
const addRoutes = (router, plugins, views) => {
  removeRoutes(router)
  for (const plugin of plugins) {
    for (const route of pluginRoutes(plugin, views)) {
      if (addedRoutes.has(route.name))
        continue
      router.addRoute(plugin.manifest.menu.area, route)
      addedRoutes.add(route.name)
    }
  }
}

// the icon namespaces of vue-awesome ("regular/square"), refused by the API
// (go/uiplugins, pf::ui_plugins) as plugin ids
const RESERVED_IDS = ['regular', 'brands']

// a manifest the UI cannot use (the API validates them, this is a safeguard)
const usable = ({ id, manifest }) => {
  if (!manifest || manifest.id !== id || RESERVED_IDS.includes(id)) {
    logError(`${id}: invalid manifest, ignored`)
    return false
  }
  if (!catalog.manifestVersions.includes(manifest.manifestVersion)) {
    logError(`${id}: unsupported manifestVersion ${manifest.manifestVersion}, ignored`)
    return false
  }
  if (!catalog.areas.includes(manifest.menu && manifest.menu.area)) {
    logError(`${id}: unsupported menu area, ignored`)
    return false
  }
  if (manifest.template === 'bundle' && !(manifest.bundle && catalog.bundle.hostApi.includes(manifest.bundle.hostApi))) {
    logError(`${id}: unsupported bundle.hostApi, ignored`)
    return false
  }
  return true
}

const deepFreeze = o => {
  if (o && typeof o === 'object' && !Object.isFrozen(o)) {
    Object.values(o).forEach(deepFreeze)
    Object.freeze(o) // also keeps Vue from making the manifest reactive
  }
  return o
}

let loading = null
let loadedFor = null

// The icons a plugin ships (manifest icons, validated by the API), registered
// as "<id>/<name>": a plugin never needs an icon added to the admin UI, nor a
// rebuild. Under its own id, a plugin cannot replace a core icon or another
// plugin's: the core icons are "<name>", "regular/<name>" or "brands/<name>",
// and no plugin id can be regular or brands (RESERVED_IDS).
const registerIcons = ({ id, manifest: { icons = {} } }) => {
  const own = Object.entries(icons).reduce((all, [name, { width, height, paths = [] }]) => ({
    ...all,
    [`${id}/${name}`]: { width, height, paths: paths.map(d => ({ d })) }
  }), {})
  if (Object.keys(own).length)
    Icon.register(own)
}

// after a failed load, the next ones wait: 1s, 2s, 4s... up to a minute, so
// that a server that keeps failing does not add a request to every navigation
let failedFor = null
let failures = 0
let retryAt = 0

// the load each manifest comes from: a page of an earlier load can still be
// mounted after a new login (store.js keeps the module of the newer one)
let generation = 0
const generations = new WeakMap()
export const manifestGeneration = manifest => generations.get(manifest) || 0

/**
 * Load the plugins once per session token and add their routes. A failure
 * leaves the UI without plugins until a later navigation, which tries again
 * once the backoff has passed.
 */
export const loadPlugins = ({ router, token, views }) => {
  if (!token)
    return Promise.resolve(false)
  if (loadedFor === token)
    return loading
  if (failedFor === token && Date.now() < retryAt)
    return Promise.resolve(false)
  loadedFor = token
  closePanel() // another session: no panel nor badge of the previous admin
  panels.badges = {}
  loading = apiCall.getQuiet('plugins')
    .then(response => {
      if (loadedFor !== token) // another session meanwhile
        return
      const { data: { items = [] } = {} } = response
      const plugins = items.filter(usable).map(deepFreeze)
      plugins.forEach(registerIcons)
      generation += 1
      plugins.forEach(({ manifest }) => generations.set(manifest, generation))
      failedFor = null
      failures = 0
      addRoutes(router, plugins, views)
      state.plugins = plugins
    })
    .catch(err => {
      logWarning('unable to load the plugins', err)
      if (loadedFor !== token)
        return
      loadedFor = null // a later navigation loads them again
      failures = (failedFor === token) ? failures + 1 : 1
      failedFor = token
      retryAt = Date.now() + Math.min(60000, 1000 * 2 ** (failures - 1))
      removeRoutes(router)
      state.plugins = []
    })
  return loading
}

export const usePlugin = id => state.plugins.find(plugin => plugin.id === id)

/**
 * Bundle plugins: their mounts, and the panel of the navbar (one open at a time)
 */
export const hasMount = (bundle, mount) => !!bundle && Array.isArray(bundle.mounts) && bundle.mounts.includes(mount)

const panels = Vue.observable({ open: null, fullscreen: false, badges: {} })

// the plugins with a navbar button the admin may use
export const navbarPlugins = () => state.plugins.filter(({ manifest: { template, bundle, menu: { can } } }) => template === 'bundle'
  && hasMount(bundle, 'navbar-panel') && canAcl(can))

// The panels under the header, one open at a time: the plugin ones (their
// id), and the core ones (CORE_PANELS, "core:" ids no plugin can register).
// The documentation viewer closes them, and they close it (App.vue).
export const LIVE_LOGS_PANEL = 'core:live-logs'
export const HISTORICAL_LOGS_PANEL = 'core:historical-logs'
export const openPanel = () => panels.open
export const togglePanel = id => {
  panels.open = (panels.open === id) ? null : id
  panels.fullscreen = false
}
export const showPanel = id => {
  if (panels.open !== id)
    panels.fullscreen = false
  panels.open = id
}
export const closePanel = () => {
  panels.open = null
  panels.fullscreen = false
}
// the badge of the navbar button of a plugin (eg unread answers): a red dot
export const panelBadge = id => panels.badges[id] || 0
export const setPanelBadge = (id, count) => { Vue.set(panels.badges, id, Math.max(0, +count || 0)) }
// the open panel over the whole page under the navbar, like the documentation
export const isPanelFullscreen = () => !!panels.open && panels.fullscreen
export const togglePanelFullscreen = () => { panels.fullscreen = !!panels.open && !panels.fullscreen }

/**
 * The API methods of a manifest the admin may use: a write method with a `can`
 * the admin does not have is not offered (no New, Clone, Save or Delete).
 */
// the API path of a plugin: /api/v1/plugin/<id>/<path>
export const pluginApiPath = (id, path) => `plugin/${id}/${path}`
export const apiPath = method => ((typeof method === 'string') ? method : method && method.path)
export const allowedApi = ({ api = {} }) => Object.entries(api).reduce((allowed, [ method, value ]) => {
  if (typeof value === 'string' || canAcl(value.can))
    allowed[method] = true
  return allowed
}, {})

/**
 * Sidebars
 */

const samePath = (a, b) => (a === b || (!!a && !!b && typeof a === 'object' && typeof b === 'object' && JSON.stringify(a) === JSON.stringify(b)))

// copy the arrays of the sections tree, items can be Promises (ignored)
const copySections = list => list.map(item => ((Array.isArray(item.items)) ? { ...item, items: copySections(item.items) } : item))

// find an item by path, at any depth
const findItem = (list, path) => {
  for (let index = 0; index < list.length; index++) {
    const item = list[index]
    if (item.path && samePath(item.path, path))
      return { list, index }
    if (Array.isArray(item.items)) {
      const found = findItem(item.items, path)
      if (found)
        return found
    }
  }
  return undefined
}

const insertItem = (id, list, item, before, after) => {
  const anchor = before || after
  if (anchor) {
    const index = list.findIndex(sibling => samePath(sibling.path, anchor))
    if (index > -1) {
      list.splice((before) ? index : index + 1, 0, item)
      return
    }
    logWarning(`${id}: sidebar item "${anchor}" not found, "${item.name}" appended`)
  }
  list.push(item)
}

// the plugins with a page in an area that the admin may open
const pagePlugins = area => state.plugins.filter(({ manifest: { menu, template, bundle } }) => menu.area === area
  && (template !== 'bundle' || hasMount(bundle, 'page')) // a bundle without a page has no sidebar item
  && canAcl(menu.can))

// the Plugins section of Configuration: its page lists them (TheSectionPlugins)
export const PLUGINS_SECTION_PATH = '/configuration/plugins'

/**
 * The plugins of the Plugins section of Configuration (no menu.section), for
 * its page: { id, path, name, title, description, icon }, translated.
 */
export const sectionPlugins = () => pagePlugins('configuration')
  .filter(({ manifest: { menu: { section } } }) => !section)
  .map(plugin => {
    const { id, manifest: { name, title, description, icon } } = plugin
    return { id, path: pluginPath(plugin), name: translate(name || title), title: translate(title), description: translate(description), icon }
  })

/**
 * Add the sidebar items of the plugins of an area (the route name of a
 * top-level view: 'configuration', 'status', ...) to its core sections. The
 * item is the manifest `name` (the `title` when absent).
 *
 * The manifest `menu`:
 *  - `section`: the path of an existing section, at any depth, the item is
 *    added to its items, in its group named `group` (untranslated) if any
 *  - without `section`: in 'configuration', the item goes in the Plugins
 *    section (added after the core ones); in the other areas, it is a new
 *    top-level section (with `menu.icon`)
 *  - `before`/`after`: the path of a sibling
 *
 * Reactive: call it in a computed, it is updated once the plugins are loaded.
 */
export const areaSections = (area, sections) => {
  const plugins = pagePlugins(area)
  if (plugins.length === 0)
    return sections
  const tree = copySections(sections)
  let pluginsSection = null
  for (const plugin of plugins) {
    const { id, manifest: { name, title, menu: { section, group, before, after, icon } } } = plugin
    const item = { name: translate(name || title), path: pluginPath(plugin), plugin: id }
    let list = tree
    if (!section && area === 'configuration') {
      if (!pluginsSection) {
        pluginsSection = { name: i18n.t('Plugins'), path: PLUGINS_SECTION_PATH, icon: 'plug', collapsable: true, items: [] }
        tree.push(pluginsSection)
      }
      list = pluginsSection.items
    }
    else if (section) {
      const found = findItem(tree, section)
      if (!found || !Array.isArray(found.list[found.index].items)) {
        logError(`${id}: sidebar section "${section}" not found, "${item.name}" ignored`)
        continue
      }
      list = found.list[found.index].items
      if (group) {
        const groupName = i18n.t(group)
        const groupItem = list.find(sibling => !sibling.path && Array.isArray(sibling.items) && [groupName, group].includes(sibling.name))
        if (!groupItem) {
          logError(`${id}: sidebar group "${group}" not found, "${item.name}" ignored`)
          continue
        }
        list = groupItem.items
      }
    }
    else if (icon)
      item.icon = icon
    insertItem(id, list, item, before, after)
  }
  return tree
}

/**
 * Form: the yup schema of a manifest form, built once per manifest.
 */

const formFields = ({ form: { fields = [], tabs = [] } }) => [ ...fields, ...tabs.reduce((all, tab) => [ ...all, ...tab.fields ], []) ]

const fieldSchema = (field, componentType) => {
  const { id = '' } = field
  let s = (types[componentType] || types.mixed)()
  for (const { fn, args = [], message } of (field.validators || [])) {
    const build = validators[fn]
    if (!build) {
      logError(`${id}: unknown validator "${fn}" ignored`)
      continue
    }
    try {
      s = build(s, args, escapeHtml(translate(message)))
    } catch (err) {
      logError(`${id}: validator "${fn}" ignored`, err)
    }
  }
  return s
}

// { a: s1, 'b.c': s2 } -> yup.object({ a: s1, b: yup.object({ c: s2 }) })
const nest = entries => {
  const tree = { children: {} }
  for (const [ namespace, s ] of entries) {
    const parts = namespace.split('.')
    let node = tree
    for (const part of parts.slice(0, -1))
      node = node.children[part] = node.children[part] || { children: {} }
    node.children[parts[parts.length - 1]] = { schema: s }
  }
  const toSchema = node => yup.object(Object.entries(node.children).reduce((shape, [ key, child ]) => {
    shape[key] = child.schema || toSchema(child)
    return shape
  }, {}))
  return toSchema(tree)
}

const schemas = new WeakMap()

export const formSchema = manifest => {
  if (!schemas.has(manifest)) {
    const entries = formFields(manifest).map(field => {
      const { type } = catalog.components[field.component] || {}
      return [ field.namespace, fieldSchema({ ...field, id: manifest.id }, type) ]
    })
    schemas.set(manifest, nest(entries))
  }
  return schemas.get(manifest)
}

// is a field shown, given the form values (manifest `when`) and the ACL (`can`)
export const isFieldVisible = (field, form) => {
  const { when, can } = field
  if (!canAcl(can))
    return false
  if (!when)
    return true
  const value = when.field.split('.').reduce((o, key) => ((o && typeof o === 'object') ? o[key] : undefined), form)
  if ('equals' in when)
    return value === when.equals
  if ('notEquals' in when)
    return value !== when.notEquals
  if ('in' in when)
    return Array.isArray(when.in) && when.in.includes(value)
  return false // a condition the API refuses (go/uiplugins Validate)
}
