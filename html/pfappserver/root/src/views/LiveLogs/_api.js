import apiCall from '@/utils/api'
import store from '@/store'

const isSaas = () => {
  const { state: { system: { summary: { saas } = {} } = {} } = {} } = store
  return !!saas
}

const prefix = () => {
  return isSaas() ? 'eslogs' : 'logs'
}

// Pin the request to a cluster peer; standalone callers omit `server` so no header is sent.
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
    // 404 = session already gone; treat as success and mark response quiet so the interceptor stays silent.
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
