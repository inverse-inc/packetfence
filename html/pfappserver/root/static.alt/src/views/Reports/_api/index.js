import apiCall from '@/utils/api'

export default {
  reports: params => {
    if (params.sort) {
      params.sort = params.sort.join(',')
    } else {
      params.sort = 'id'
    }
    if (params.fields) {
      params.fields = params.fields.join(',')
    }
    return apiCall.get('dynamic_reports', { params }).then(response => {
      return response.data
    })
  },
  report: id => {
    return apiCall.get(['dynamic_report', id]).then(response => {
      return response.data.item
    })
  },
  searchReport: body => {
    return apiCall.post(['dynamic_report', body.id, 'search'], body).then(response => {
      return response.data.items
    })
  }
}
