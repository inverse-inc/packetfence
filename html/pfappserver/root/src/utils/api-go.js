// Backend-specific API wrapper for endpoints served by a Go service
// (pfpki under `/api/v1/pki/*`, or the api-frontend DAL routes under
// `/api/v1/<dal>_logs`, `/api/v1/wrixes`, etc.).
//
// Re-exports the shared `apiCall` instance from `./api` and overlays a
// `getAll(url, params)` method that walks every page of a cursor-paginated
// list endpoint and resolves a single `{ data: { items: [...all items] } }`.
//
// Go list handlers ALWAYS set `nextCursor` (it advances unconditionally past
// the end), so a missing `nextCursor` cannot signal end-of-data. Instead the
// walker terminates on the first of:
//   - empty `items` page (cursor already past the end), or
//   - `items.length >= total` (DAL) / `>= total_count` (pfpki), or
//   - cursor that fails to advance (defensive — should not happen).

import apiCall, { _encodeURL } from './api'

// Re-export everything `api.js` exports as named exports (e.g.
// `fileUploadPaths`, `baseURL`, `documentationCall`) so callers can import
// shared utilities from the same module they get the wrapped `apiCall` from.
export * from './api'

async function getAll (url, params = {}) {
  const { limit = 1000, ...extraParams } = params
  const items = []
  let cursor = 0
  let more = true
  while (more) {
    const response = await apiCall.request({
      method: 'get',
      url: _encodeURL(url),
      params: { ...extraParams, limit, cursor }
    })
    const data = (response && response.data) || {}
    const pageItems = data.items || []
    items.push(...pageItems)
    const total = (data.total !== undefined ? data.total : data.total_count)
    const nextCursor = data.nextCursor
    if (pageItems.length === 0) {
      more = false
    } else if (total !== undefined && total !== null && items.length >= total) {
      more = false
    } else if (nextCursor === undefined || nextCursor === null || nextCursor === cursor) {
      more = false
    } else {
      cursor = nextCursor
    }
  }
  return { data: { items } }
}

export default new Proxy(apiCall, {
  get (target, prop, receiver) {
    if (prop === 'getAll') return getAll
    return Reflect.get(target, prop, receiver)
  }
})
