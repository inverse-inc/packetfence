import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/network_behavior_policies', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/network_behavior_policies').then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/network_behavior_policies/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/network_behavior_policies', data).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'network_behavior_policy', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'network_behavior_policy', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'network_behavior_policy', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'network_behavior_policy', id])
  }
}
