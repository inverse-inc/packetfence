import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get(['fingerbank', 'all', 'dhcp6_enterprises'], { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    const { scope, ...rest } = body
    if (scope)
      return apiCall.post(`fingerbank/${scope}/dhcp6_enterprises/search`, rest).then(response => {
        return response.data
      })
    else
      return apiCall.post('fingerbank/all/dhcp6_enterprises/search', body).then(response => {
        return response.data
      })
  },
  item: id => {
    return apiCall.get(['fingerbank', 'all', 'dhcp6_enterprise', id]).then(response => {
      return response.data.item
    })
  },
  create: data => {
    return apiCall.post('fingerbank/local/dhcp6_enterprises', data).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['fingerbank', 'local', 'dhcp6_enterprise', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['fingerbank', 'local', 'dhcp6_enterprise', id])
  }
}
