import apiCall from '@/utils/api'

export default {
  search: query => {
    return apiCall.get('users').then(response => {
      return response.data.items
    })
  }
}
