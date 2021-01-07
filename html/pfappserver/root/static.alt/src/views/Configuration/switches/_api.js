import apiCall from '@/utils/api'

export default {
  switches: params => {
    return apiCall.get(['config', 'switches'], { params: { ...params, raw: 1 } }).then(response => {
      return response.data
    })
  },
  switchesOptions: switchGroup => {
    if (switchGroup) {
      return apiCall.options(['config', 'switches'], { params: { type: switchGroup } }).then(response => {
        return response.data
      })
    } else {
      return apiCall.options(['config', 'switches']).then(response => {
        return response.data
      })
    }
  },
  switchesBulkImport: body => {
    return apiCall.post('config/switches/bulk_import', body).then(response => {
      return response.data.items
    })
  },
  switche: id => {
    return apiCall.get(['config', 'switch', id], { params: { skip_inheritance: true } }).then(response => {
      return response.data.item
    })
  },
  switcheQuiet: id => {
    return apiCall.getQuiet(['config', 'switch', id], { params: { skip_inheritance: true } }).then(response => {
      return response.data.item
    })
  },
  switchOptions: id => {
    return apiCall.options(['config', 'switch', id]).then(response => {
      return response.data
    })
  },
  createSwitch: data => {
    const post = data.quiet ? 'postQuiet' : 'post'
    return apiCall[post]('config/switches', data).then(response => {
      return response.data
    })
  },
  updateSwitch: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'switch', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSwitch: id => {
    return apiCall.delete(['config', 'switch', id])
  },
  invalidateSwitchCache: id => {
    return apiCall.post(['config', 'switch', id, 'invalidate_cache'])
  }
}
