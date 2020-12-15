import apiCall from '@/utils/api'

export default {
  layer2Networks: params => {
    return apiCall.get('config/l2_networks', { params }).then(response => {
      return response.data
    })
  },
  layer2NetworksOptions: () => {
    return apiCall.options('config/l2_networks').then(response => {
      return response.data
    })
  },
  layer2Network: id => {
    return apiCall.get(['config', 'l2_network', id]).then(response => {
      return response.data.item
    })
  },
  layer2NetworkOptions: id => {
    return apiCall.options(['config', 'l2_network', id]).then(response => {
      return response.data
    })
  },
  updateLayer2Network: data => {
    return apiCall.patch(['config', 'l2_network', data.id], data).then(response => {
      return response.data
    })
  }
}
