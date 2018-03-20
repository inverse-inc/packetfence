import apiCall from '@/utils/api'

export default {
  all: params => {
    return apiCall.get('users', { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('users/search', body).then(response => {
      return response.data
    })
  },
  user: userId => {
    return apiCall.get(`user/${userId}`).then(response => {
      return response.data.item
    })
  }
}
