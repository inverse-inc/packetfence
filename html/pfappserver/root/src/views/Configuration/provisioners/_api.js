import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get(['config', 'provisionings'], { params }).then(response => {
      return response.data
    })
  },
  listOptions: provisioningType => {
    return apiCall.options(['config', 'provisionings'], { params: { type: provisioningType } }).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/pki_providers/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/provisionings', data).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'provisioning', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'provisioning', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'provisioning', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'provisioning', id])
  }
}
