import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get(['config', 'switches'], { params: { limit: 1000, ...params, raw: 1 } }).then(response => {
      return response.data
    })
  },
  listOptions: switchGroup => {
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
  search: data => {
    return apiCall.post('config/switches/search', data).then(response => {
      return response.data
    })
  },
  bulkImportAsync: body => {
    return apiCall.postQuiet('config/switches/bulk_import', { ...body, async: true })
  },
  create: data => {
    const post = data.quiet ? 'postQuiet' : 'post'
    return apiCall[post]('config/switches', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'switch', id], { params: { skip_inheritance: true } }).then(response => {
      return response.data.item
    })
  },
  itemQuiet: id => {
    return apiCall.getQuiet(['config', 'switch', id], { params: { skip_inheritance: true } }).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'switch', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'switch', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'switch', id])
  },
  invalidateCache: id => {
    return apiCall.post(['config', 'switch', id, 'invalidate_cache'])
  },
  precreateAcls: id => {
    return apiCall.post(['config', 'switch', id, 'precreate_acls'])
  }
}
