import apiCall from '@/utils/api'

export default {
  provisionings: params => {
    return apiCall.get(['config', 'provisionings'], { params }).then(response => {
      return response.data
    })
  },
  provisioningsOptions: provisioningType => {
    return apiCall.options(['config', 'provisionings'], { params: { type: provisioningType } }).then(response => {
      return response.data
    })
  },
  provisioning: id => {
    return apiCall.get(['config', 'provisioning', id]).then(response => {
      return response.data.item
    })
  },
  provisioningOptions: id => {
    return apiCall.options(['config', 'provisioning', id]).then(response => {
      return response.data
    })
  },
  createProvisioning: data => {
    return apiCall.post('config/provisionings', data).then(response => {
      return response.data
    })
  },
  updateProvisioning: data => {
    return apiCall.patch(['config', 'provisioning', data.id], data).then(response => {
      return response.data
    })
  },
  deleteProvisioning: id => {
    return apiCall.delete(['config', 'provisioning', id])
  }
}
