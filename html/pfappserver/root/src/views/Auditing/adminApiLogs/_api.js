import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('admin_api_audit_logs', { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('admin_api_audit_logs/search', body).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.getQuiet(`admin_api_audit_log/${id}`).then(response => {
      return response.data.item
    })
  }
}