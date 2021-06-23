import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/self_services', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/self_services').then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/self_services/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/self_services', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'self_service', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'self_service', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'self_service', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'self_service', id])
  }
}
