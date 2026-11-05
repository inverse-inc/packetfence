/**
 * Admin UI plugins (see docs/ui-plugins/README.md).
 *
 * Plugin services register in redis, the API lists the ones whose manifest is
 * valid (GET /api/v1/ui_plugins). Once logged in, the routes and sidebar items
 * of their manifests are added and their pages are built from the manifests
 * with the core components only (registry.js).
 *
 * Without any plugin, nothing is added.
 *
 * Do not import '@/router' or '@/store' here: this module is imported while the
 * router is being built.
 */
import Vue from 'vue'
import apiCall from '@/utils/api'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { types, validators } from './registry'
import catalog from './catalog.json'

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

const addedRoutes = new Set()

// the routes of a plugin, the same as the _router.js of a core view
const pluginRoutes = (plugin, views) => {
  const { id, manifest: { template, api, menu: { can } } } = plugin
  const names = pluginRouteNames(plugin)
  const path = `plugins/${id}`
  const meta = { plugin: id, ...((can) ? { can } : {}) } // can: '<verb> <target>'
  if (template === 'resource')
    return [{ path, name: names.collection, component: views.resource, props: () => ({ pluginId: id }), meta }]
  return [
    { path, name: names.collection, component: views.search, props: () => ({ pluginId: id }), meta },
    ...((api.create)
      ? [
        { path: `${path}/new`, name: names.new, component: views.item, props: () => ({ pluginId: id, isNew: true }), meta },
        { path: `${path}/:id/clone`, name: names.clone, component: views.item, props: route => ({ pluginId: id, id: route.params.id, isClone: true }), meta }
      ]
      : []
    ),
    { path: `${path}/:id`, name: names.item, component: views.item, props: route => ({ pluginId: id, id: route.params.id }), meta }
  ]
}

const addRoutes = (router, plugins, views) => {
  for (const plugin of plugins) {
    for (const route of pluginRoutes(plugin, views)) {
      if (addedRoutes.has(route.name))
        continue
      router.addRoute(plugin.manifest.menu.area, route)
      addedRoutes.add(route.name)
    }
  }
}

// a manifest the UI cannot use (the API validates them, this is a safeguard)
const usable = ({ id, manifest }) => {
  if (!manifest || manifest.id !== id) {
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

/**
 * Load the plugins once per session token and add their routes. A failure
 * leaves the UI without plugins.
 */
export const loadPlugins = ({ router, token, views }) => {
  if (!token)
    return Promise.resolve(false)
  if (loadedFor === token)
    return loading
  loadedFor = token
  loading = apiCall.getQuiet('ui_plugins')
    .then(response => {
      const { data: { items = [] } = {} } = response
      const plugins = items.filter(usable).map(deepFreeze)
      addRoutes(router, plugins, views)
      state.plugins = plugins
    })
    .catch(err => {
      logWarning('unable to load the plugins', err)
      state.plugins = []
    })
  return loading
}

export const usePlugin = id => state.plugins.find(plugin => plugin.id === id)

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

/**
 * Add the sidebar items of the plugins of an area (the route name of a
 * top-level view: 'configuration', 'status', ...) to its core sections.
 *
 * The manifest `menu`:
 *  - `section`: the path of an existing section, at any depth, the item is
 *    added to its items, in its group named `group` (untranslated) if any
 *  - without `section`: the item is a new top-level section
 *  - `before`/`after`: the path of a sibling
 *
 * Reactive: call it in a computed, it is updated once the plugins are loaded.
 */
export const areaSections = (area, sections) => {
  const plugins = state.plugins.filter(({ manifest: { menu } }) => menu.area === area)
  if (plugins.length === 0)
    return sections
  const tree = copySections(sections)
  for (const plugin of plugins) {
    const { id, manifest: { title, menu: { section, group, before, after, icon, can } } } = plugin
    const item = { name: translate(title), path: pluginPath(plugin), plugin: id }
    if (can)
      item.can = can
    let list = tree
    if (section) {
      const found = findItem(tree, section)
      if (!found || !Array.isArray(found.list[found.index].items)) {
        logError(`${id}: sidebar section "${section}" not found, "${item.name}" ignored`)
        continue
      }
      list = found.list[found.index].items
      if (group) {
        const name = i18n.t(group)
        const groupItem = list.find(sibling => !sibling.path && Array.isArray(sibling.items) && [name, group].includes(sibling.name))
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
      s = build(s, args, translate(message))
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

// is a field shown, given the form values (manifest `when`)
export const isFieldVisible = (field, form) => {
  const { when } = field
  if (!when)
    return true
  const value = when.field.split('.').reduce((o, key) => ((o && typeof o === 'object') ? o[key] : undefined), form)
  if ('equals' in when)
    return value === when.equals
  if ('notEquals' in when)
    return value !== when.notEquals
  if ('in' in when)
    return when.in.includes(value)
  return true
}
