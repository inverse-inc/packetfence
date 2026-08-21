import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/connectors', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/connectors').then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/connectors/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/connectors', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'connector', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'connector', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'connector', data.id], data).then(response => {
      return response.data
    })
  },
  sort: data => {
    return apiCall.patch('config/connectors/sort_items', data).then(response => {
      return response
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'connector', id])
  },
  status: () => {
    return apiCall.get('config/connectors/status').then(response => {
      return response.data
    })
  },

  remoteStatus: id => {
    return apiCall.get(['pfconnector-remotes', id, 'status']).then(response => {
      return response.data
    })
  },
  remoteRestart: id => {
    return apiCall.post(['pfconnector-remotes', id, 'restart']).then(response => {
      return response.data
    })
  },
  terminalSession: id => {
    return apiCall.post('terminal', { pfconnector_id: id }).then(response => {
      return response.data
    })
  },
  terminalAuthorize: (id, uuid) => {
    return apiCall.get(['terminal', id, 'authorize', uuid]).then(response => {
      return response.data
    })
  }
}
