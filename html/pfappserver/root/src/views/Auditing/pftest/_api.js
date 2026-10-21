import apiCall from '@/utils/api'

// pftest fan-out: always hit the cluster_* endpoint. The backend collapses
// the standalone case to a single-item response, so the frontend treats
// every reply uniformly.
export default {
  runAuthentication: body => {
    return apiCall.post('pftest/cluster/authentication', body).then(response => response.data)
  },
  runProfileFilter: body => {
    return apiCall.post('pftest/cluster/profile_filter', body).then(response => response.data)
  },
  // Lists configured authentication sources so the user can pick a subset
  // instead of typing source IDs by hand.
  listSources: () => {
    return apiCall.getQuiet('config/sources').then(response => response.data.items || [])
  }
}
