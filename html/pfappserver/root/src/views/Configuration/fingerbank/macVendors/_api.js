import apiCall from '@/utils/api'

export default {
  fingerbankMacVendors: params => {
    return apiCall.get(['fingerbank', 'all', 'mac_vendors'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchMacVendors: body => {
    return apiCall.post('fingerbank/all/mac_vendors/search', body).then(response => {
      return response.data
    })
  },
  fingerbankMacVendor: id => {
    return apiCall.get(['fingerbank', 'all', 'mac_vendor', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateMacVendor: data => {
    return apiCall.post('fingerbank/local/mac_vendors', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateMacVendor: data => {
    return apiCall.patch(['fingerbank', 'local', 'mac_vendor', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteMacVendor: id => {
    return apiCall.delete(['fingerbank', 'local', 'mac_vendor', id])
  }
}
