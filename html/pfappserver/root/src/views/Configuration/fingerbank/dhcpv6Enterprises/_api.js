import apiCall from '@/utils/api'

export default {
  fingerbankDhcpv6Enterprises: params => {
    return apiCall.get(['fingerbank', 'all', 'dhcp6_enterprises'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchDhcpv6Enterprises: body => {
    return apiCall.post('fingerbank/all/dhcp6_enterprises/search', body).then(response => {
      return response.data
    })
  },
  fingerbankDhcpv6Enterprise: id => {
    return apiCall.get(['fingerbank', 'all', 'dhcp6_enterprise', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateDhcpv6Enterprise: data => {
    return apiCall.post('fingerbank/local/dhcp6_enterprises', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateDhcpv6Enterprise: data => {
    return apiCall.patch(['fingerbank', 'local', 'dhcp6_enterprise', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteDhcpv6Enterprise: id => {
    return apiCall.delete(['fingerbank', 'local', 'dhcp6_enterprise', id])
  }
}
