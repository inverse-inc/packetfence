import apiCall from '@/utils/api'

export default {
  all: params => {
    if (params.sort) {
      params.sort = params.sort.join(',')
    } else {
      params.sort = 'mac'
    }
    if (params.fields) {
      params.fields = params.fields.join(',')
    }
    return apiCall.get('nodes', { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('nodes/search', body).then(response => {
      return response.data
    })
  },
  node: mac => {
    return apiCall.get(`node/${mac}`).then(response => {
      return response.data.item
    })
  },
  fingerbankInfo: mac => {
    return apiCall.get(`node/${mac}/fingerbank_info`).then(response => {
      return response.data.item
    })
  },
  ip4logOpen: mac => {
    return apiCall.get(`ip4logs/open/${mac}`).then(response => {
      return response.data.item
    })
  },
  ip4logHistory: mac => {
    return apiCall.get(`ip4logs/history/${mac}`).then(response => {
      return response.data.items
    })
  },
  ip6logOpen: mac => {
    return apiCall.get(`ip6logs/open/${mac}`).then(response => {
      return response.data.item
    })
  },
  ip6logHistory: mac => {
    return apiCall.get(`ip6logs/history/${mac}`).then(response => {
      return response.data.items
    })
  },
  locationlogs: mac => {
    const search = {
      query: { op: 'and', values: [ { field: 'mac', op: 'equals', value: mac } ] },
      limit: 100,
      cursor: '0'
    }
    return apiCall.post('locationlogs/search', search).then(response => {
      return response.data.items
    })
  },
  violations: mac => {
    const search = {
      query: { op: 'and', values: [ { field: 'mac', op: 'equals', value: mac } ] },
      limit: 100,
      cursor: '0'
    }
    return apiCall.post('violations/search', search).then(response => {
      return response.data.items
    })
  },
  createNode: body => {
    return apiCall.post('nodes', body).then(response => {
      return response.data
    })
  },
  updateNode: body => {
    return apiCall.patch(`node/${body.mac}`, body).then(response => {
      return response.data
    })
  },
  deleteNode: mac => {
    return apiCall.delete(`node/${mac}`)
  },
  registerBulkNodes: body => {
    return apiCall.post('nodes/bulk_register', body).then(response => {
      return response.data
    })
  },
  deregisterBulkNodes: body => {
    return apiCall.post('nodes/bulk_deregister', body).then(response => {
      return response.data
    })
  },
  clearViolationNode: mac => {
    return apiCall.post(`node/${mac}/closeviolations`).then(response => {
      return response.data
    })
  },
  applyViolationBulkNodes: body => {
    return apiCall.post('nodes/bulk_apply_violation', body).then(response => {
      return response.data
    })
  },
  clearViolationBulkNodes: body => {
    return apiCall.post('nodes/bulk_close_violations', body).then(response => {
      return response.data
    })
  },
  reevaluateAccessBulkNodes: body => {
    return apiCall.post('nodes/bulk_reevaluate_access', body).then(response => {
      return response.data
    })
  },
  restartSwitchportBulkNodes: body => {
    return apiCall.post('nodes/bulk_restart_switchport', body).then(response => {
      return response.data
    })
  }
}
