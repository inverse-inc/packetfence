import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/pki_providers', { params }).then(response => {
      return response.data
    })
  },
  listOptions: providerType => {
    return apiCall.options(['config', 'pki_providers'], { params: { type: providerType } }).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/pki_providers/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/pki_providers', data).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'pki_provider', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'pki_provider', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'pki_provider', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'pki_provider', id])
  }
}
