import apiCall from '@/utils/api'

export default {
  search: params => {
    return apiCall.post('config/roles/search', params).then(response => {
      return response.data
    })
  }
}
