import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/portal_modules', { params }).then(response => {
      return response.data
    })
  },
  listOptions: sourceType => {
    return apiCall.options(['config', 'portal_modules'], { params: { type: sourceType } }).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/portal_modules/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/portal_modules', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'portal_module', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'portal_module', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'portal_module', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'portal_module', id])
  }
}
