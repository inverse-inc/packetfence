import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('radius_audit_logs', { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('radius_audit_logs/search', body).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['radius_audit_log', id]).then(response => {
      return response.data.item
    })
  }
}