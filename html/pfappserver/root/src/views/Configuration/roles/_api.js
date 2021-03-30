import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/roles', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/roles').then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'role', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'role', id]).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/roles', data).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'role', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'role', id])
  },
  reassign: data => {
    return apiCall.patch(['config', 'role', data.from, 'reassign'], { id: data.to })
  },
  search: data => {
    return apiCall.post('config/roles/search', data).then(response => {
      return response.data
    })
  }
}
