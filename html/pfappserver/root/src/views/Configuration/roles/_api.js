import apiCall from '@/utils/api'

export default {
  roles: params => {
    return apiCall.get('config/roles', { params }).then(response => {
      return response.data
    })
  },
  rolesOptions: () => {
    return apiCall.options('config/roles').then(response => {
      return response.data
    })
  },
  role: id => {
    return apiCall.get(['config', 'role', id]).then(response => {
      return response.data.item
    })
  },
  roleOptions: id => {
    return apiCall.options(['config', 'role', id]).then(response => {
      return response.data
    })
  },
  createRole: data => {
    return apiCall.post('config/roles', data).then(response => {
      return response.data
    })
  },
  updateRole: data => {
    return apiCall.patch(['config', 'role', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRole: id => {
    return apiCall.delete(['config', 'role', id])
  },
  reassignRole: data => {
    return apiCall.patch(['config', 'role', data.from, 'reassign'], { id: data.to })
  }
}
