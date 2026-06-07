import apiCall from '@/utils/api'

// The historical-logs view always hits the cluster_history endpoint. The
// backend controller handles standalone (no cluster_enabled) by running the
// local query in-process and wrapping it as a single-item list, so the
// frontend code path stays uniform regardless of topology.
export default {
  options: () => {
    return apiCall.options('logs/history').then(response => response.data)
  },
  query: body => {
    return apiCall.postQuiet('logs/cluster_history', body).then(response => response.data)
  }
}
