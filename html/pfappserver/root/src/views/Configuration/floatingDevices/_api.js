import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/floating_devices', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/floating_devices').then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'floating_device', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'floating_device', id]).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/floating_devices', data).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'floating_device', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'floating_device', id])
  },
  search: data => {
    return apiCall.post('config/floating_devices/search', data).then(response => {
      return response.data
    })
  }
}
