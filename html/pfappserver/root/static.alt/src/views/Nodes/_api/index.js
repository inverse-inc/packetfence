import apiCall from '@/utils/api'

export default {
  all: () => {
    return apiCall.get('nodes').then(response => {
      return response.data.items
    })
  },
  search: query => {
    return apiCall.post('nodes/search', query).then(response => {
      return response.data.items
    })
  },
  node: id => {
    return apiCall.get(`node/${id}`).then(response => {
      return response.data.item
    })
  }
}
