import apiCall from '@/utils/api'

export default {
  networkBehaviorPolicies: params => {
    return apiCall.get('config/network_behavior_policies', { params }).then(response => {
      return response.data
    })
  },
  networkBehaviorPoliciesOptions: () => {
    return apiCall.options('config/network_behavior_policies').then(response => {
      return response.data
    })
  },
  networkBehaviorPolicy: id => {
    return apiCall.get(['config', 'network_behavior_policy', id]).then(response => {
      return response.data.item
    })
  },
  networkBehaviorPolicyOptions: id => {
    return apiCall.options(['config', 'network_behavior_policy', id]).then(response => {
      return response.data
    })
  },
  createNetworkBehaviorPolicy: data => {
    return apiCall.post('config/network_behavior_policies', data).then(response => {
      return response.data
    })
  },
  updateNetworkBehaviorPolicy: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'network_behavior_policy', data.id], data).then(response => {
      return response.data
    })
  },
  deleteNetworkBehaviorPolicy: id => {
    return apiCall.delete(['config', 'network_behavior_policy', id])
  }
}
