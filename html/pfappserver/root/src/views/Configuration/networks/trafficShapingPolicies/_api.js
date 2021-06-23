import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/traffic_shaping_policies', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/traffic_shaping_policies').then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/traffic_shaping_policies/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/traffic_shaping_policies', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'traffic_shaping_policy', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'traffic_shaping_policy', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'traffic_shaping_policy', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'traffic_shaping_policy', id])
  }
}
