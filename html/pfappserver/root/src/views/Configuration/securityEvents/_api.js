import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/security_events', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/security_events').then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/security_events/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/security_events', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'security_event', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'security_event', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'security_event', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'security_event', id])
  }
}
