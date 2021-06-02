import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get(['fingerbank', 'all', 'dhcp_vendors'], { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    const { scope, ...rest } = body
    if (scope)
      return apiCall.post(`fingerbank/${scope}/dhcp_vendors/search`, rest).then(response => {
        return response.data
      })
    else
      return apiCall.post('fingerbank/all/dhcp_vendors/search', body).then(response => {
        return response.data
      })
  },
  item: id => {
    return apiCall.get(['fingerbank', 'all', 'dhcp_vendor', id]).then(response => {
      return response.data.item
    })
  },
  create: data => {
    return apiCall.post('fingerbank/local/dhcp_vendors', data).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['fingerbank', 'local', 'dhcp_vendor', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['fingerbank', 'local', 'dhcp_vendor', id])
  }
}
