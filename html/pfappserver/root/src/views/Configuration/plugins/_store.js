/**
* Admin UI plugins
*
* A plugin is defined in conf/admin_ui_plugins.conf, its API is proxied under /api/v1/plugins/<id>/
* and it describes its section of the admin UI with a JSON manifest:
*
* {
*   "title": "Connectors",                 // menu entry (group when more than 1 collection)
*   "section": "system_configuration",     // configuration section of the menu (default: system_configuration)
*   "collections": [
*     {
*       "id": "connectors",
*       "title": "Connectors",             // menu entry and list title
*       "item_title": "Connector",         // title of an item
*       "collection": "config/connectors", // list, search, create and OPTIONS (relative to the plugin API)
*       "resource": "config/connector",    // get, update, delete and OPTIONS of an item (<resource>/<id>)
*       "columns": [ { "key": "id", "label": "Identifier", "searchable": true, "sortable": true } ],
*       "form": { "tabs": [ { "title": "General", "fields": [ { "key": "id", "label": "Identifier", "text": "help" } ] } ] },
*       "actions": [ { "label": "Install command", "method": "GET", "endpoint": "install-command/{id}", "display": "modal-text", "field": "command" } ],
*       "status": { "endpoint": "config/connectors/status", "field": "status" }
*     }
*   ]
* }
*/
import Vue from 'vue'
import api from './_api'
import { loadBundle } from './_host'

const state = Vue.observable({
  isLoading: false,
  isLoaded: false,
  generation: 0, // incremented on each load, the manifests may have changed
  routesChanged: false, // the routes of /configuration were rebuilt by the last load
  plugins: []
})

let loading

const errorMessage = err => {
  const { message: errMessage, response: { data: { message } = {} } = {} } = err || {}
  return message || errMessage
}

// the UI bundle of the plugin, when its manifest names one
const loadUi = plugin => {
  const { manifest: { module } = {} } = plugin
  if (!module)
    return Promise.resolve(plugin)
  return loadBundle(plugin.id, module)
    .then(ui => ({ ...plugin, ui }))
    .catch(err => ({ ...plugin, available: false, error: errorMessage(err) }))
}

const loadManifest = plugin => {
  const manifest = (plugin.manifest)
    ? Promise.resolve(plugin.manifest)
    : api.manifest(plugin.id)
  return manifest
    .then(manifest => loadUi({ ...plugin, manifest, available: true }))
    .catch(err => ({ ...plugin, manifest: undefined, available: false, error: errorMessage(err) || plugin.error }))
}

let routesApplied = false

// the routes of the UI bundles replace the static routes of the sections they replace
const applyRoutes = plugins => {
  const available = plugins.filter(plugin => plugin.available)
  const routes = available
    .filter(plugin => plugin.ui && Array.isArray(plugin.ui.routes))
    .reduce((routes, plugin) => [...routes, ...plugin.ui.routes], [])
  const replaced = available
    .filter(plugin => plugin.replaces)
    .map(plugin => plugin.replaces)
  if (!routes.length && !replaced.length && !routesApplied)
    return Promise.resolve(false)
  routesApplied = routes.length > 0 || replaced.length > 0
  // imported here, the router imports the routes of this module
  return import('@/router').then(({ setConfigurationPluginRoutes }) => {
    setConfigurationPluginRoutes(routes, replaced)
    return true
  })
}

export const load = (force = false) => {
  if (loading && !force)
    return loading
  state.isLoading = true
  loading = api.plugins()
    .then(plugins => Promise.all((plugins || []).map(loadManifest)))
    .then(plugins => applyRoutes(plugins).then(routesChanged => {
      state.routesChanged = routesChanged
      return plugins
    }))
    .catch(() => ([])) // plugins must never break the admin UI
    .then(plugins => {
      state.plugins = plugins
      state.generation++
      state.isLoading = false
      state.isLoaded = true
      return plugins
    })
  return loading
}

export const reload = () => load(true)

export const usePlugins = () => state

export const getPlugin = id => state.plugins.find(plugin => plugin.id === id)

export const getCollection = (pluginId, collectionId) => {
  const plugin = getPlugin(pluginId)
  if (!plugin || !plugin.manifest)
    return undefined
  const { manifest: { collections = [] } = {} } = plugin
  return collections.find(collection => collection.id === collectionId)
}

// static menu entries replaced by an available plugin
export const useReplaced = () => state.plugins
  .filter(plugin => plugin.available && plugin.replaces)
  .map(plugin => plugin.replaces)

// true once after the routes were rebuilt, the pending navigation must be matched again
export const consumeRoutesChanged = () => {
  const changed = state.routesChanged
  state.routesChanged = false
  return changed
}
