import apiCall from '@/utils/api'

export default {
  fingerbankDhcpVendors: params => {
    return apiCall.get(['fingerbank', 'all', 'dhcp_vendors'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchDhcpVendors: body => {
    return apiCall.post('fingerbank/all/dhcp_vendors/search', body).then(response => {
      return response.data
    })
  },
  fingerbankDhcpVendor: id => {
    return apiCall.get(['fingerbank', 'all', 'dhcp_vendor', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateDhcpVendor: data => {
    return apiCall.post('fingerbank/local/dhcp_vendors', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateDhcpVendor: data => {
    return apiCall.patch(['fingerbank', 'local', 'dhcp_vendor', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteDhcpVendor: id => {
    return apiCall.delete(['fingerbank', 'local', 'dhcp_vendor', id])
  }
}
