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
    return apiCall.get(`dynamic_report/${id}`).then(response => {
      return response.data.item
    })
  },
  createReport: body => {
    return apiCall.post('dynamic_reports', body).then(response => {
      return response.data
    })
  },
  updateReport: body => {
    return apiCall.patch(`dynamic_report/${body.id}`, body).then(response => {
      return response.data
    })
  },
  deleteReport: id => {
    return apiCall.delete(`dynamic_report/${id}`)
  },
  searchReport: body => {
    return apiCall.post(`dynamic_report/${body.id}/search`, body).then(response => {
      return response.data.items
    })
  }
}
