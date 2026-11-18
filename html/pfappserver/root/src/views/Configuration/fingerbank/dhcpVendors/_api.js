import apiCall from '@/utils/api'

// The Fingerbank data is read-only
export default {
  list: params => {
    return apiCall.get(['fingerbank', 'all', 'dhcp_vendors'], { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('fingerbank/all/dhcp_vendors/search', body).then(response => {
      return response.data
    })
  }
}
