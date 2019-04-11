import apiCall from '@/utils/api'

export default {
  all: params => {
    if (params.sort) {
      params.sort = params.sort.join(',')
    } else {
      params.sort = 'pid'
    }
    if (params.fields) {
      params.fields = params.fields.join(',')
    }
    return apiCall.get('users', { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('users/search', body).then(response => {
      return response.data
    })
  },
  user: pid => {
    return apiCall.get(`user/${pid}`).then(response => {
      return response.data.item
    })
  },
  nodes: pid => {
    return apiCall.get(`user/${pid}/nodes`).then(response => {
      return response.data.items
    })
  },
  securityEvents: pid => {
    return apiCall.get(`user/${pid}/security_events`).then(response => {
      return response.data.items
    })
  },
  createUser: body => {
    return apiCall.post('users', body).then(response => {
      return response.data
    })
  },
  updateUser: body => {
    return apiCall.patch(`user/${body.pid}`, body).then(response => {
      return response.data
    })
  },
  deleteUser: pid => {
    return apiCall.delete(`user/${pid}`)
  },
  unassignUserNodes: pid => {
    return apiCall.post(`user/${pid}/unassign_nodes`)
  },
  bulkUserRegisterNodes: body => {
    return apiCall.post(`users/bulk_register`, body).then(response => {
      return response.data.items
    })
  },
  bulkUserDeregisterNodes: body => {
    return apiCall.post(`users/bulk_deregister`, body).then(response => {
      return response.data.items
    })
  },
  bulkUserApplySecurityEvent: body => {
    return apiCall.post(`users/bulk_apply_security_event`, body).then(response => {
      return response.data.items
    })
  },
  bulkUserCloseSecurityEvents: body => {
    return apiCall.post(`users/bulk_close_security_events`, body).then(response => {
      return response.data.items
    })
  },
  bulkUserApplyRole: body => {
    return apiCall.post(`users/bulk_apply_role`, body).then(response => {
      return response.data.items
    })
  },
  bulkUserApplyBypassRole: body => {
    return apiCall.post(`users/bulk_apply_bypass_role`, body).then(response => {
      return response.data.items
    })
  },
  bulkUserReevaluateAccess: body => {
    return apiCall.post(`users/bulk_reevaluate_access`, body).then(response => {
      return response.data.items
    })
  },
  bulkUserRefreshFingerbank: body => {
    return apiCall.post(`users/bulk_fingerbank_refresh`, body).then(response => {
      return response.data.items
    })
  }
}
