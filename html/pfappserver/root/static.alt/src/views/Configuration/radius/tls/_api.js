import apiCall from '@/utils/api'

export default {
  radiusTlss: params => {
    return apiCall.get('config/radiusd/tls_profiles', { params }).then(response => {
      return response.data
    })
  },
  radiusTlssOptions: () => {
    return apiCall.options('config/radiusd/tls_profiles').then(response => {
      return response.data
    })
  },
  radiusTls: id => {
    return apiCall.get(['config', 'radiusd', 'tls_profile', id]).then(response => {
      return response.data.item
    })
  },
  radiusTlsOptions: id => {
    return apiCall.options(['config', 'radiusd', 'tls_profile', id]).then(response => {
      return response.data
    })
  },
  createRadiusTls: data => {
    return apiCall.post('config/radiusd/tls_profiles', data).then(response => {
      return response.data
    })
  },
  updateRadiusTls: data => {
    return apiCall.patch(['config', 'radiusd', 'tls_profile', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRadiusTls: id => {
    return apiCall.delete(['config', 'radiusd', 'tls_profile', id])
  }
}
