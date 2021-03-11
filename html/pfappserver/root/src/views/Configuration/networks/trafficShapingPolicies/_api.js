import apiCall from '@/utils/api'

export default {
  trafficShapingPolicies: params => {
    return apiCall.get('config/traffic_shaping_policies', { params }).then(response => {
      return response.data
    })
  },
  trafficShapingPoliciesOptions: () => {
    return apiCall.options('config/traffic_shaping_policies').then(response => {
      return response.data
    })
  },
  trafficShapingPolicy: id => {
    return apiCall.get(['config', 'traffic_shaping_policy', id]).then(response => {
      return response.data.item
    })
  },
  trafficShapingPolicyOptions: id => {
    return apiCall.options(['config', 'traffic_shaping_policy', id]).then(response => {
      return response.data
    })
  },
  createTrafficShapingPolicy: data => {
    return apiCall.post('config/traffic_shaping_policies', data).then(response => {
      return response.data
    })
  },
  updateTrafficShapingPolicy: data => {
    return apiCall.patch(['config', 'traffic_shaping_policy', data.id], data).then(response => {
      return response.data
    })
  },
  deleteTrafficShapingPolicy: id => {
    return apiCall.delete(['config', 'traffic_shaping_policy', id])
  }
}
