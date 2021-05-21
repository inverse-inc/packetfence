import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/domains', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/domains').then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'domain', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'domain', id]).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/domains', data).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'domain', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'domain', id])
  },
  test: id => {
    return apiCall.getQuiet(['config', 'domain', id, 'test_join']).then(response => {
      return response.data
    }).catch(err => {
      throw err
    })
  },
  join: data => {
    return apiCall.post(['config', 'domain', data.id, 'join'], data).then(response => {
      return response.data
    })
  },
  rejoin: data => {
    return apiCall.post(['config', 'domain', data.id, 'rejoin'], data).then(response => {
      return response.data
    })
  },
  unjoin: data => {
    return apiCall.post(['config', 'domain', data.id, 'unjoin'], data).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/domains/search', data).then(response => {
      return response.data
    })
  }
}
