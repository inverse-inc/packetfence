import apiCall from '@/utils/api'

export default {
  list: params => {
    if (params.sort) {
      params.sort = params.sort.join(',')
    } else {
      params.sort = 'created_at,mac'
    }
    if (params.fields) {
      params.fields = params.fields.join(',')
    }
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