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
    return apiCall.get(['user', pid]).then(response => {
      return response.data.item
    })
  },
  nodes: pid => {
    return apiCall.get(['user', pid, 'nodes']).then(response => {
      return response.data.items
    })
  },
  securityEvents: pid => {
    return apiCall.get(['user', pid, 'security_events']).then(response => {
      return response.data.items
    })
  },
  createUser: body => {
    const post = body.quiet ? 'postQuiet' : 'post'
    return apiCall[post]('users', body).then(response => {
      return response.data
    })
  },
  updateUser: body => {
    const patch = body.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['user', body.pid], body).then(response => {
      return response.data
    })
  },
  deleteUser: pid => {
    return apiCall.delete(['user', pid])
  },
  createPassword: body => {
    const post = body.quiet ? 'postQuiet' : 'post'
    return apiCall[post](['user', body.pid, 'password'], body).then(response => {
      return response.data
    })
  },
  updatePassword: body => {
    const patch = body.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['user', body.pid, 'password'], body).then(response => {
      return response.data
    })
  },
  previewEmail: body => {
    return apiCall.postQuiet('email/preview', body).then(response => {
      return response.data
    })
  },
  sendEmail: body => {
    return apiCall.postQuiet('email/send', body).then(response => {
      return response.data
    })
  },
  unassignUserNodes: pid => {
    return apiCall.post(['user', id, 'unassign_nodes'])
  },
  bulkRegisterNodes: body => {
    return apiCall.post(['users', 'bulk_register'], body).then(response => {
      return response.data.items
    })
  },
  bulkDeregisterNodes: body => {
    return apiCall.post(['users', 'bulk_deregister'], body).then(response => {
      return response.data.items
    })
  },
  bulkApplySecurityEvent: body => {
    return apiCall.post(['users', 'bulk_apply_security_event'], body).then(response => {
      return response.data.items
    })
  },
  bulkCloseSecurityEvents: body => {
    return apiCall.post(['users', 'bulk_close_security_events'], body).then(response => {
      return response.data.items
    })
  },
  bulkApplyRole: body => {
    return apiCall.post(['users', 'bulk_apply_role'], body).then(response => {
      return response.data.items
    })
  },
  bulkApplyBypassRole: body => {
    return apiCall.post(['users', 'bulk_apply_bypass_role'], body).then(response => {
      return response.data.items
    })
  },
  bulkReevaluateAccess: body => {
    return apiCall.post(['users', 'bulk_reevaluate_access'], body).then(response => {
      return response.data.items
    })
  },
  bulkRefreshFingerbank: body => {
    return apiCall.post(['users', 'bulk_fingerbank_refresh'], body).then(response => {
      return response.data.items
    })
  },
  bulkDelete: body => {
    return apiCall.post(['users', 'bulk_delete'], body).then(response => {
      return response.data.items
    })
  }
}
