import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/admin_roles', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/admin_roles').then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'admin_role', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'admin_role', id]).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/admin_roles', data).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'admin_role', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'admin_role', id])
  },
  search: data => {
    return apiCall.post('config/admin_roles/search', data).then(response => {
      return response.data
    })
  }
}
