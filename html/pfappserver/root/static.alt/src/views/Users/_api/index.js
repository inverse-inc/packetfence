import apiCall from '@/utils/api'

export default {
  all: () => {
    return apiCall.get('users').then(response => {
      return response.data.items
    })
  },
  search: query => {
    return apiCall.post('users', query).then(response => {
      return response.data.items
    })
  },
  user: userId => {
    return apiCall.get(`user/${userId}`).then(response => {
      return response.data.item
    })
  }
}
