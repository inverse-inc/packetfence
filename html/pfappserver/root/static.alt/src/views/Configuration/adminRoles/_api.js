import apiCall from '@/utils/api'

export default {
  adminRoles: params => {
    return apiCall.get('config/admin_roles', { params }).then(response => {
      return response.data
    })
  },
  adminRolesOptions: () => {
    return apiCall.options('config/admin_roles').then(response => {
      return response.data
    })
  },
  adminRole: id => {
    return apiCall.get(['config', 'admin_role', id]).then(response => {
      return response.data.item
    })
  },
  adminRoleOptions: id => {
    return apiCall.options(['config', 'admin_role', id]).then(response => {
      return response.data
    })
  },
  createAdminRole: data => {
    return apiCall.post('config/admin_roles', data).then(response => {
      return response.data
    })
  },
  updateAdminRole: data => {
    return apiCall.patch(['config', 'admin_role', data.id], data).then(response => {
      return response.data
    })
  },
  deleteAdminRole: id => {
    return apiCall.delete(['config', 'admin_role', id])
  }
}
