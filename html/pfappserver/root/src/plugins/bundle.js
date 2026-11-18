/**
 * Bundle plugins (manifest template "bundle", see
 * https://github.com/akainverse/packetfence-plugin-example): the plugin's own UI code.
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
import * as composition from '@vue/composition-api'
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

// a quiet request: the plugin handles its own errors, core shows no
// notification for it (an array answer stays an array)
const quietTransform = data => {
  if (typeof data !== 'string')
    return data // a blob, an arraybuffer
  let parsed
  try {
    parsed = JSON.parse(data)
  } catch (e) {
    return data
  }
  if (parsed && typeof parsed === 'object')
    Object.defineProperty(parsed, 'quiet', { value: true, enumerable: !Array.isArray(parsed) })
  return parsed
}

// apiCall, its paths relative to /api/v1/plugin/<id>/, quiet unless
// config.quiet is false
const scopedApi = id => {
  const scoped = path => `plugin/${encodeURIComponent(id)}/${`${path}`.replace(/^\/+/, '')}`
  const request = ({ quiet = true, ...config }) => apiCall.request({
    ...config,
    url: scoped(config.url || ''),
    ...((quiet) ? { transformResponse: [quietTransform] } : {})
  })
  return Object.freeze({
    request,
    get: (path, config = {}) => request({ ...config, method: 'get', url: path }),
    options: (path, config = {}) => request({ ...config, method: 'options', url: path }),
    post: (path, data, config = {}) => request({ ...config, method: 'post', url: path, data }),
    put: (path, data, config = {}) => request({ ...config, method: 'put', url: path, data }),
    patch: (path, data, config = {}) => request({ ...config, method: 'patch', url: path, data }),
    delete: (path, config = {}) => request({ ...config, method: 'delete', url: path })
  })
}

/**
 * The host API, version 1: what the admin UI gives a bundle.
 *
 *   id           the plugin id
 *   Vue          the Vue of the admin UI (its global components: BootstrapVue,
 *                icon (vue-awesome), ...)
 *   composition  @vue/composition-api, as installed on that Vue (ref,
 *                computed, watch, ...): a bundle cannot ship its own
 *   i18n         the VueI18n of the admin UI: give it to the root of the
 *                bundle ({ i18n: host.i18n }) for $t
 *   api          apiCall for /api/v1/plugin/<id>/<path>: request, get, options,
 *                post, put, patch, delete. Quiet: no notification, unless
 *                { quiet: false }
 *   notify       notify(level, message): a notification of the admin UI
 *                (level: info, success, warning, danger)
 *   can          can('read plugin'), the ACL of the admin, as a manifest can
 *   t            i18n.t of the admin UI, locale() its language
 *   navigate     router.push of the admin UI
 */
const LEVELS = ['info', 'success', 'warning', 'danger']

export const hostApi = (id, { router, store }) => Object.freeze({
  version: 1,
  id,
  Vue,
  composition,
  i18n,
  api: scopedApi(id),
  notify: (level, message) => store.dispatch(`notification/${(LEVELS.includes(level)) ? level : 'info'}`, { message: `${message}` }),
  can: expression => can(expression),
  t: (...args) => i18n.t(...args),
  locale: () => i18n.locale,
  navigate: to => router.push(to)
})
