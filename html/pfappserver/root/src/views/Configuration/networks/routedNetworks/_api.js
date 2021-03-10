import apiCall from '@/utils/api'

export default {
  routedNetworks: params => {
    return apiCall.get('config/routed_networks', { params }).then(response => {
      return response.data
    })
  },
  routedNetworksOptions: () => {
    return apiCall.options('config/routed_networks').then(response => {
      return response.data
    })
  },
  routedNetwork: id => {
    return apiCall.get(['config', 'routed_network', id]).then(response => {
      return response.data.item
    })
  },
  routedNetworkOptions: id => {
    return apiCall.options(['config', 'routed_network', id]).then(response => {
      return response.data
    })
  },
  createRoutedNetwork: data => {
    return apiCall.post('config/routed_networks', data).then(response => {
      return response.data
    })
  },
  updateRoutedNetwork: data => {
    return apiCall.patch(['config', 'routed_network', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRoutedNetwork: id => {
    return apiCall.delete(['config', 'routed_network', id])
  }
}
