import apiCall from '@/utils/api'

// Pin the request to a cluster peer; standalone callers omit `server` so no header is sent.
const serverConfig = server => {
  if (server && server.management_ip) {
    return { headers: { 'X-PacketFence-Server': server.management_ip } }
  }
  return {}
}

// /logs/history is served by the Go log-tailer plugin inside each node's
// api-frontend. Cluster fan-out happens client-side — one request per peer
// via the X-PacketFence-Server haproxy routing, exactly like the cluster
// LiveLogs sessions — so no server-side fan-out endpoint exists.
export default {
  options: () => {
    return apiCall.options('logs/history').then(response => response.data)
  },
  query: (body, server) => {
    return apiCall.postQuiet('logs/history', body, serverConfig(server)).then(response => response.data)
  }
}
