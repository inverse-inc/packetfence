import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('dhcp_option82s', { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('dhcp_option82s/search', body).then(response => {
      return response.data
    })
  },
  getItem: mac => {
    return apiCall.get(['dhcp_option82', mac]).then(response => {
      return response.data.item
    })
  }
}