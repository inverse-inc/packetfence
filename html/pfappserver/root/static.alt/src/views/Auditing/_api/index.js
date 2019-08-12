import apiCall from '@/utils/api'

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
  }
}
