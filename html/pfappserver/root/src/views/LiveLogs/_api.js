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
    // Stop is idempotent and often fires from navigation/unload paths after
    // the server already reaped the session (5min idle timeout), so a 404
    // is treated as success and the response is marked quiet to keep the
    // interceptor silent. A 404 can however also mean a wrong session id or
    // a request that landed on the wrong cluster node — annotate the result
    // with gone:true and leave a console.debug trail with the peer context
    // so those cases stay diagnosable instead of vanishing.
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
    }).then(response => {
      if (response.status === 404) {
        const peer = (server && server.management_ip) || 'default route'
        console.debug(`live-log session ${id} already gone on ${peer} (stop returned 404)`) // eslint-disable-line no-console
        return { ...response.data, gone: true }
      }
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
