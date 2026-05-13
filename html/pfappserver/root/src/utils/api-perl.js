// Backend-specific API wrapper for endpoints served by the Perl UnifiedApi
// (typical fallthrough route in Caddy — anything not picked up by a Go
// service like pfpki or the api-frontend DAL).
//
// Re-exports the shared `apiCall` instance from `./api` and overlays a
// `getAll(url, params)` method that walks every page of a cursor-paginated
// list endpoint and resolves a single `{ data: { items: [...all items] } }`.
//
// Perl's `pf::UnifiedApi::Search::Builder` omits `nextCursor` from the
// response after returning the last page, which is how this walker
// terminates.

import apiCall, { _encodeURL } from './api'

async function getAll (url, params = {}) {
  const { limit = 1000, ...extraParams } = params
  const items = []
  let cursor
  let more = true
  while (more) {
    const pageParams = { ...extraParams, limit }
    if (cursor !== undefined) pageParams.cursor = cursor
    const response = await apiCall.request({
      method: 'get',
      url: _encodeURL(url),
      params: pageParams
    })
    const pageItems = (response && response.data && response.data.items) || []
    items.push(...pageItems)
    const nextCursor = response && response.data && response.data.nextCursor
    if (nextCursor === undefined || nextCursor === null || nextCursor === cursor) {
      more = false
    } else {
      cursor = nextCursor
    }
  }
  return { data: { items } }
}

// Transparent delegate: callers can use everything `apiCall` exposes
// (`get`, `post`, `request`, the `*Quiet` variants, calling `apiCall({...})`
// directly, etc.) AND the new `getAll`. Property access falls through to the
// shared `apiCall`; function-call forwarding is handled automatically by
// `Proxy` since `apiCall` is itself a callable axios instance.
export default new Proxy(apiCall, {
  get (target, prop, receiver) {
    if (prop === 'getAll') return getAll
    return Reflect.get(target, prop, receiver)
  }
})
