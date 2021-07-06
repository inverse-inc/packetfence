import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/clouds', { params }).then(response => {
      return response.data
    })
  },
  listOptions: cloudType => {
    return apiCall.options(['config', 'clouds'], { params: { type: cloudType } }).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/billing_tiers/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/clouds', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'cloud', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'cloud', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'cloud', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'cloud', id])
  }
}
