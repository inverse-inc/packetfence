/**
 * The API of a plugin page, built from the manifest `api` the same way the
 * _api.js of the core views are written: one method by path, with a fixed verb
 * (catalog.json api.verbs). Only the methods of the manifest are defined, a
 * view does not offer what is missing (eg: no create, no "New" button).
 */
import apiCall from '@/utils/api'

// the path of a method, '{id}' replaced by the (encoded) id of the item
const url = (path, id) => path.split('/').map(part => ((part === '{id}') ? id : part))

const methods = {
  list: path => params => apiCall.get(path, { params }).then(response => response.data),
  listOptions: path => () => apiCall.options(path).then(response => response.data),
  search: path => data => apiCall.post(path, data).then(response => response.data),
  create: path => data => apiCall.post(path, data).then(response => response.data),
  item: path => id => apiCall.get(url(path, id)).then(response => response.data.item),
  itemOptions: path => id => apiCall.options(url(path, id)).then(response => response.data),
  update: path => data => apiCall.patch(url(path, data.id), data).then(response => response.data),
  delete: path => id => apiCall.delete(url(path, id))
}

export const makeApi = ({ api = {} }) => Object.entries(api).reduce((made, [ method, path ]) => {
  if (method in methods)
    made[method] = methods[method](path)
  return made
}, {})

export default makeApi
