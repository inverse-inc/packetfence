import apiCall from '@/utils/api'

export default {
  fingerbankDevices: params => {
    return apiCall.get(['fingerbank', 'all', 'devices'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchDevices: body => {
    return apiCall.post('fingerbank/all/devices/search', body).then(response => {
      return response.data
    })
  },
  fingerbankDevice: id => {
    return apiCall.get(['fingerbank', 'all', 'device', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateDevice: data => {
    return apiCall.post('fingerbank/local/devices', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateDevice: data => {
    return apiCall.patch(['fingerbank', 'local', 'device', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteDevice: id => {
    return apiCall.delete(['fingerbank', 'local', 'device', id])
  }
}
