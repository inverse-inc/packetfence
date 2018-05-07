import apiCall from '@/utils/api'

export default {
  all: params => {
    if (params.sort) {
      params.sort = params.sort.join(',')
    }
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
