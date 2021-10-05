import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/mfas', { params }).then(response => {
      return response.data
    })
  },
  listOptions: mfaType => {
    return apiCall.options(['config', 'mfas'], { params: { type: mfaType } }).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/mfas/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/mfas', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'mfa', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'mfa', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'mfa', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'mfa', id])
  }
}
