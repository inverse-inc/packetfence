import apiCall from '@/utils/api'

export default {
  all: params => {
    return apiCall.get('nodes', { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('nodes/search', body).then(response => {
      return response.data
    })
  },
  node: id => {
    return apiCall.get(`node/${id}`).then(response => {
      return response.data.item
    })
  }
}
