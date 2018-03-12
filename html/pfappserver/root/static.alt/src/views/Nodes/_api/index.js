import apiCall from '@/utils/api'

export default {
  search: query => {
    return apiCall.get('nodes').then(response => {
      return response.data.items
    })
  }
}
