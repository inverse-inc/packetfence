import apiCall from '@/utils/api'

export default {
  selfServices: params => {
    return apiCall.get('config/self_services', { params }).then(response => {
      return response.data
    })
  },
  selfServicesOptions: () => {
    return apiCall.options('config/self_services').then(response => {
      return response.data
    })
  },
  selfService: id => {
    return apiCall.get(['config', 'self_service', id]).then(response => {
      return response.data.item
    })
  },
  selfServiceOptions: id => {
    return apiCall.options(['config', 'self_service', id]).then(response => {
      return response.data
    })
  },
  createSelfService: data => {
    return apiCall.post('config/self_services', data).then(response => {
      return response.data
    })
  },
  updateSelfService: data => {
    return apiCall.patch(['config', 'self_service', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSelfService: id => {
    return apiCall.delete(['config', 'self_service', id])
  }
}
