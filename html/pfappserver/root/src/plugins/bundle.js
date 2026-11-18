/**
 * Bundle plugins (manifest template "bundle", see
 * docs/developer/ui_plugins.asciidoc): the plugin's own UI code.
 *
 * The code is the JavaScript module its package installed on the server
 * (conf/plugins.d/<id>.js, checked against the sha256 of its descriptor). The
 * API serves it at GET /api/v1/plugins/<id>/bundle.js with the admin token: it
 * is loaded with apiCall, then imported from a Blob URL. It is loaded once per
 * session token.
 *
 * The module exports:
 *
 *   export default {
 *     hostApi: 1,
 *     mount (el, host, { kind }) { ...; return () => { ... } } // the unmount
 *   }
 *
 * mount renders the plugin in el, kind is the mount ("page", "navbar-panel"),
 * host is the host API below. It returns the function that undoes it.
 */
import Vue from 'vue'
import apiCall from '@/utils/api'
import i18n from '@/utils/locale'
import { can } from './acl'

const PREFIX = '[pf-ui-plugins]'

// the versions of the host API this admin UI provides (catalog.json bundle.hostApi)
export const HOST_API_VERSIONS = [1]

// the modules, by plugin id, for the session they were loaded in
const modules = new Map()
let loadedFor = null

/**
 * The module of a bundle plugin: a Promise of its default export.
 */
export const loadBundle = (id, token) => {
  if (loadedFor !== token) {
    modules.clear()
    loadedFor = token
  }
  if (!modules.has(id)) {
    const loading = apiCall.request({
      method: 'get',
      url: `plugins/${encodeURIComponent(id)}/bundle.js`,
      responseType: 'text',
      transformResponse: [data => data]
    })
      .then(({ data }) => {
        const url = URL.createObjectURL(new Blob([data], { type: 'text/javascript' }))
        return import(/* webpackIgnore: true */ url)
          .finally(() => URL.revokeObjectURL(url))
      })
      .then(module => {
        const bundle = module && module.default
        if (!bundle || typeof bundle.mount !== 'function')
          throw new Error(`${id}: the bundle has no default export with a mount function`)
        if (!HOST_API_VERSIONS.includes(bundle.hostApi))
          throw new Error(`${id}: the bundle needs the host API ${bundle.hostApi}, this admin UI provides ${HOST_API_VERSIONS.join(', ')}`)
        return bundle
      })
      .catch(err => {
        modules.delete(id) // the next mount tries again
        // eslint-disable-next-line no-console
        console.error(PREFIX, err)
        throw err
      })
    modules.set(id, loading)
  }
  return modules.get(id)
}

// apiCall, its paths relative to /api/v1/plugin/<id>/
const scopedApi = id => {
  const scoped = path => `plugin/${encodeURIComponent(id)}/${`${path}`.replace(/^\/+/, '')}`
  return Object.freeze({
    request: (config = {}) => apiCall.request({ ...config, url: scoped(config.url || '') }),
    get: (path, config) => apiCall.get(scoped(path), config),
    options: (path, config) => apiCall.options(scoped(path), config),
    post: (path, data, config) => apiCall.post(scoped(path), data, config),
    put: (path, data, config) => apiCall.put(scoped(path), data, config),
    patch: (path, data, config) => apiCall.patch(scoped(path), data, config),
    delete: (path, config) => apiCall.request({ ...config, method: 'delete', url: scoped(path) })
  })
}

/**
 * The host API, version 1: what the admin UI gives a bundle.
 *
 *   id          the plugin id
 *   Vue         the Vue of the admin UI (its global components: BootstrapVue,
 *               icon (vue-awesome), ...)
 *   api         apiCall for /api/v1/plugin/<id>/<path>: request, get, options,
 *               post, put, patch, delete
 *   can         can('read plugin'), the ACL of the admin, as a manifest can
 *   t           i18n.t of the admin UI, locale() its language
 *   navigate    router.push of the admin UI
 */
export const hostApi = (id, { router }) => Object.freeze({
  version: 1,
  id,
  Vue,
  api: scopedApi(id),
  can: expression => can(expression),
  t: (...args) => i18n.t(...args),
  locale: () => i18n.locale,
  navigate: to => router.push(to)
})
