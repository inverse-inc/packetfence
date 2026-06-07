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
    // We bypass apiCall.delete because:
    //  - its (url, data, config) override is easy to mis-pass (data vs config
    //    confusion already cost us X-PacketFence-Server on cluster peers);
    //  - its response is NOT marked `quiet`, so a 404 from the Go log-tailer
    //    surfaces as a red "Unable to find this session" notification.
    //
    // Use apiCall.request directly and set:
    //  - validateStatus to accept 404 as a success — the tail session may
    //    already be gone (golongpoll idle-evicted it, peer restarted, header
    //    lost because the user has a stale cached bundle, …) and the cleanup
    //    goal is reached either way;
    //  - transformResponse to inject `quiet: true` so the shared response
    //    interceptor in utils/api.js does not pop a notification on the
    //    (now-success-treated) 404.
    return apiCall.request({
      method: 'delete',
      url: `${prefix()}/tail/${encodeURIComponent(id)}`,
      validateStatus: status => (status >= 200 && status < 300) || status === 404,
      transformResponse: [data => {
        let jsonData
        try { jsonData = JSON.parse(data) } catch (e) { jsonData = {} }
        return Object.assign({ quiet: true }, jsonData)
      }],
      ...serverConfig(server)
    }).then(response => response.data)
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
