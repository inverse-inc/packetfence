import apiCall from '@/utils/api'

export default {
  list: params => {
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
  search: body => {
    return apiCall.post('radius_audit_logs/search', body).then(response => {
      return response.data
    })
  },
  getItem: id => {
    return apiCall.get(['radius_audit_log', id]).then(response => {
      return response.data.item
    })
  }
}