import apiCall from '@/utils/api'

export default {
  list: params => {
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
  search: body => {
    return apiCall.post('admin_api_audit_logs/search', body).then(response => {
      return response.data
    })
  },
  getItem: id => {
    return apiCall.getQuiet(`admin_api_audit_log/${id}`).then(response => {
      return response.data.item
    })
  }
}