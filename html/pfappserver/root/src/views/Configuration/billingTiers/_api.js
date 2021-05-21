import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/billing_tiers', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/billing_tiers').then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'billing_tier', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'billing_tier', id]).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/billing_tiers', data).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'billing_tier', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'billing_tier', id])
  },
  search: data => {
    return apiCall.post('config/billing_tiers/search', data).then(response => {
      return response.data
    })
  }
}
