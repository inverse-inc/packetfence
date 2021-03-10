import apiCall from '@/utils/api'

export default {
  radiusEaps: params => {
    return apiCall.get('config/radiusd/eap_profiles', { params }).then(response => {
      return response.data
    })
  },
  radiusEapsOptions: () => {
    return apiCall.options('config/radiusd/eap_profiles').then(response => {
      return response.data
    })
  },
  radiusEap: id => {
    return apiCall.get(['config', 'radiusd', 'eap_profile', id]).then(response => {
      return response.data.item
    })
  },
  radiusEapOptions: id => {
    return apiCall.options(['config', 'radiusd', 'eap_profile', id]).then(response => {
      return response.data
    })
  },
  createRadiusEap: data => {
    return apiCall.post('config/radiusd/eap_profiles', data).then(response => {
      return response.data
    })
  },
  updateRadiusEap: data => {
    return apiCall.patch(['config', 'radiusd', 'eap_profile', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRadiusEap: id => {
    return apiCall.delete(['config', 'radiusd', 'eap_profile', id])
  }
}
