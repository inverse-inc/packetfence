import apiCall from '@/utils/api'

// The Fingerbank data is read-only
export default {
  list: params => {
    return apiCall.get(['fingerbank', 'all', 'devices'], { params }).then(response => {
      return response.data
    })
  },
  classes: () => {
    return apiCall.get('fingerbank/all_device_classes').then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('fingerbank/all/devices/search', body).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['fingerbank', 'all', 'device', id]).then(response => {
      return response.data.item
    })
  }
}
