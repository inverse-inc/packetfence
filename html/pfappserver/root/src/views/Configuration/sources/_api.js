import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/sources', { params }).then(response => {
      return response.data
    })
  },
  listOptions: sourceType => {
    return apiCall.options(['config', 'sources'], { params: { type: sourceType } }).then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('config/sources/search', body).then(response => {
      return response.data
    })
  },
  sort: data => {
    return apiCall.patch('config/sources/sort_items', data).then(response => {
      return response
    })
  },
  create: data => {
    return apiCall.post('config/sources', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'source', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'source', id]).then(response => {
      return response.data
    })
  },
  saml: id => {
    return apiCall.get(['config', 'source', id, 'saml_metadata']).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'source', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'source', id])
  },
  test: data => {
    return apiCall.postQuiet('config/sources/test', data).then(response => {
      return response
    })
  }
}
