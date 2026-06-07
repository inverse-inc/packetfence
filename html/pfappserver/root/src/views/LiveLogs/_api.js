import apiCall from '@/utils/api'
import store from '@/store'

const isSaas = () => {
  const { state: { system: { summary: { saas } = {} } = {} } = {} } = store
  return !!saas
}

const prefix = () => {
  return isSaas() ? 'eslogs' : 'logs'
}

// Build an axios config that pins the request to a specific cluster peer.
// Standalone callers pass `server === undefined` and get an empty config so
// no X-PacketFence-Server header is ever sent (the haproxy-admin LUA on
// standalone has no <ip>-api backend and would 503).
const serverConfig = server => {
  if (server && server.management_ip) {
    return { headers: { 'X-PacketFence-Server': server.management_ip } }
  }
  return {}
}

export default {
  create: (body, server) => {
    if (isSaas()) {
      return apiCall.postQuiet(`eslogs/tail`, body).then(response => {
        return response.data
      })
    }
    return apiCall.post(`logs/tail`, body, serverConfig(server)).then(response => {
      return response.data
    })
  },
  delete: (id, server) => {
    if (isSaas()) {
      return Promise.resolve({})
    }
    // apiCall.delete is overridden in src/utils/api.js with a (url, data, config)
    // signature (it's in the same group as post/put/patch), not axios's standard
    // (url, config). Passing serverConfig as the 2nd arg would land the header
    // object in the request BODY and silently drop X-PacketFence-Server, which
    // sends every cluster-peer DELETE to the local node's default `api` backend
    // -> 404. data must be null so the third positional argument is read as config.
    return apiCall.delete([prefix(), 'tail', id], null, serverConfig(server)).then(response => {
      return response.data
    })
  },
  item: (id, pollBody, server) => {
    if (isSaas() && pollBody) {
      return apiCall.postQuiet(`eslogs/tail`, pollBody).then(response => {
        return response.data
      })
    }
    return apiCall.getQuiet(`${prefix()}/tail/${id}`, { performance: false, ...serverConfig(server) }).then(response => {
      return response.data
    })
  },
  options: () => {
    return apiCall.options(`${prefix()}/tail`).then(response => {
      return response.data
    })
  },
  touch: (id, server) => {
    if (isSaas()) {
      return Promise.resolve({})
    }
    return apiCall.postQuiet([prefix(), 'tail', id, 'touch'], {}, serverConfig(server)).then(response => {
      return response.data
    })
  }
}
