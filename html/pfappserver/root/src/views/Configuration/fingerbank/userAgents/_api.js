import apiCall from '@/utils/api'

// The Fingerbank data is read-only
export default {
  list: params => {
    return apiCall.get(['fingerbank', 'all', 'user_agents'], { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('fingerbank/all/user_agents/search', body).then(response => {
      return response.data
    })
  }
}
