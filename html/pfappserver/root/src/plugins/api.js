/**
 * The API of a plugin page, built from the manifest `api` the same way the
 * _api.js of the core views are written: one method by path, with a fixed verb
 * (catalog.json api.verbs). Only the methods of the manifest are defined, a
 * view does not offer what is missing (eg: no create, no "New" button).
 *
 * The paths are relative to the plugin service: /api/v1/plugin/<id>/<path>,
 * proxied by the API to the plugin, a manifest cannot reach a core API.
 *
 * The answers of a plugin are not trusted like the ones of core: before the
 * core interceptors of utils/api.js see them, the texts core renders as HTML
 * (the notifications, the API errors of the form fields) are escaped, and the
 * patterns of the OPTIONS meta (regular expressions the browser would run)
 * are dropped.
 */
import apiCall from '@/utils/api'
import { apiPath, escapeHtml, pluginApiPath } from './'

// an item id is one path segment: never empty, "." or ".." (the browser would
// resolve them, leaving the path of the plugin)
const segment = id => {
  const value = `${id}`
  if (['', '.', '..'].includes(value))
    throw new Error(`invalid item id "${value}"`)
  return value
}

// the path of a method, '{id}' replaced by the (encoded) id of the item
const url = (path, id) => path.split('/').map(part => ((part === '{id}') ? segment(id) : part))

const escapeMessages = list => ((Array.isArray(list))
  ? list.map(item => ((item && typeof item === 'object')
    ? {
      ...item,
      ...(('message' in item) ? { message: escapeHtml(`${item.message}`) } : {}),
      ...(('field' in item) ? { field: escapeHtml(`${item.field}`) } : {})
    }
    : item))
  : list)

const withoutPatterns = meta => ((meta && typeof meta === 'object' && !Array.isArray(meta))
  ? Object.entries(meta).reduce((safe, [ key, value ]) => {
    if (key !== 'pattern')
      safe[key] = (value && typeof value === 'object') ? withoutPatterns(value) : value
    return safe
  }, {})
  : meta)

// the answer of a plugin, safe for the core interceptors and components
export const sanitize = data => {
  let json = data
  if (typeof data === 'string') {
    try {
      json = JSON.parse(data)
    } catch (e) {
      return {}
    }
  }
  if (!json || typeof json !== 'object' || Array.isArray(json))
    return json
  return {
    ...json,
    ...(('message' in json) ? { message: escapeHtml(`${json.message}`) } : {}),
    ...(('errors' in json) ? { errors: escapeMessages(json.errors) } : {}),
    ...(('warnings' in json) ? { warnings: escapeMessages(json.warnings) } : {}),
    ...(('meta' in json) ? { meta: withoutPatterns(json.meta) } : {})
  }
}

const config = { transformResponse: [ sanitize ] }

const methods = {
  list: path => params => apiCall.get(path, { ...config, params }).then(response => response.data),
  listOptions: path => () => apiCall.options(path, config).then(response => response.data),
  search: path => data => apiCall.post(path, data, config).then(response => response.data),
  create: path => data => apiCall.post(path, data, config).then(response => response.data),
  item: path => id => apiCall.get(url(path, id), config).then(response => response.data.item),
  itemOptions: path => id => apiCall.options(url(path, id), config).then(response => response.data),
  update: path => data => apiCall.patch(url(path, data.id), data, config).then(response => response.data),
  delete: path => id => apiCall.delete(url(path, id), undefined, config)
}

// a method is a path, or { path, can } (the ACL is checked by store.js useStore)
export const makeApi = ({ id, api = {} }) => Object.entries(api).reduce((made, [ method, value ]) => {
  if (method in methods)
    made[method] = methods[method](pluginApiPath(id, apiPath(value)))
  return made
}, {})

export default makeApi
