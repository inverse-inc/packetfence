import apiCall from '@/utils/api'
import store from '@/store'
import Vue from 'vue'

export default {
  allDhcpOption82Logs: params => {
    if (params.sort) {
      params.sort = params.sort.join(',')
    } else {
      params.sort = 'created_at,mac'
    }
    if (params.fields) {
      params.fields = params.fields.join(',')
    }
    return apiCall.get('dhcp_option82s', { params }).then(response => {
      return response.data
    })
  },
  searchDhcpOption82Logs: body => {
    return apiCall.post('dhcp_option82s/search', body).then(response => {
      return response.data
    })
  },
  getDhcpOption82Log: mac => {
    return apiCall.get(['dhcp_option82', mac]).then(response => {
      return response.data.item
    })
  },
  allRadiusLogs: params => {
    if (params.sort) {
      params.sort = params.sort.join(',')
    } else {
      params.sort = 'created_at,mac'
    }
    if (params.fields) {
      params.fields = params.fields.join(',')
    }
    return apiCall.get('radius_audit_logs', { params }).then(response => {
      return response.data
    })
  },
  searchRadiusLogs: body => {
    return apiCall.post('radius_audit_logs/search', body).then(response => {
      return response.data
    })
  },
  getRadiusLog: id => {
    return apiCall.get(['radius_audit_log', id]).then(response => {
      return response.data.item
    })
  },
  allDnsLogs: params => {
    if (params.sort) {
      params.sort = params.sort.join(',')
    } else {
      params.sort = 'created_at'
    }
    if (params.fields) {
      params.fields = params.fields.join(',')
    }
    return apiCall.get('dns_audit_logs', { params }).then(response => {
      return response.data
    })
  },
  searchDnsLogs: body => {
    return apiCall.post('dns_audit_logs/search', body).then(response => {
      return response.data
    })
  },
  getDnsLog: id => {
    return apiCall.get(`dns_audit_log/${id}`).then(response => {
      return response.data.item
    })
  },
  setPassthroughs: passthroughs => {
    return apiCall.patch('config/base/fencing', { passthroughs: passthroughs.join(',') }).then(response => {
      // Clear cached values
      Vue.set(store.state.config, 'baseFencing', false)
      if (store.state.$_bases) {
        Vue.set(store.state.$_bases.cache, 'fencing', false)
      }
      return response
    })
  },
  allAdminApiAuditLogs: params => {
    if (params.sort) {
      params.sort = params.sort.join(',')
    } else {
      params.sort = 'created_at'
    }
    if (params.fields) {
      params.fields = params.fields.join(',')
    }
    return apiCall.get('admin_api_audit_logs', { params }).then(response => {
      return response.data
    })
  },
  searchAdminApiAuditLogs: body => {
    return apiCall.post('admin_api_audit_logs/search', body).then(response => {
      return response.data
    })
  },
  getAdminApiAuditLog: id => {
    return apiCall.getQuiet(`admin_api_audit_log/${id}`).then(response => {
      return response.data.item
    })
  },
  createLogTailSession: body => {
    return apiCall.post('logs/tail', body).then(response => {
      return response.data
    })
  },
  deleteLogTailSession: id => {
    return apiCall.delete(['logs', 'tail', id ]).then(response => {
      return response.data
    })
  },
  getLogTailSession: id => {
    return apiCall.get(`logs/tail/${id}`, { performance: false }).then(response => {
      return response.data
    })
  },
  optionsLogTailSession: () => {
    return apiCall.options('logs/tail').then(response => {
      return response.data
    })
  },
  touchLogTailSession: id => {
    return apiCall.postQuiet(['logs', 'tail', id, 'touch']).then(response => {
      return response.data
    })
  }
}
