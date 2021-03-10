import apiCall from '@/utils/api'

export default {
  radiusOcsps: params => {
    return apiCall.get('config/radiusd/ocsp_profiles', { params }).then(response => {
      return response.data
    })
  },
  radiusOcspsOptions: () => {
    return apiCall.options('config/radiusd/ocsp_profiles').then(response => {
      return response.data
    })
  },
  radiusOcsp: id => {
    return apiCall.get(['config', 'radiusd', 'ocsp_profile', id]).then(response => {
      return response.data.item
    })
  },
  radiusOcspOptions: id => {
    return apiCall.options(['config', 'radiusd', 'ocsp_profile', id]).then(response => {
      return response.data
    })
  },
  createRadiusOcsp: data => {
    return apiCall.post('config/radiusd/ocsp_profiles', data).then(response => {
      return response.data
    })
  },
  updateRadiusOcsp: data => {
    return apiCall.patch(['config', 'radiusd', 'ocsp_profile', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRadiusOcsp: id => {
    return apiCall.delete(['config', 'radiusd', 'ocsp_profile', id])
  }
}
