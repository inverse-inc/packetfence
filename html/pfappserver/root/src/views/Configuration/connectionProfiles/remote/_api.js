import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get(['config', 'remote_connection_profiles'], { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/remote_connection_profiles').then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'remote_connection_profile', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'remote_connection_profile', id]).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/remote_connection_profiles', data).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'remote_connection_profile', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'remote_connection_profile', id])
  },
  sort: data => {
    return apiCall.patch('config/remote_connection_profiles/sort_items', data).then(response => {
      return response
    })
  },
  search: data => {
    return apiCall.post('config/remote_connection_profiles/search', data).then(response => {
      return response.data
    })
  }
}
