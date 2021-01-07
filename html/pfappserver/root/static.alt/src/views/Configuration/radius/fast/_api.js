import apiCall from '@/utils/api'

export default {
  radiusFasts: params => {
    return apiCall.get('config/radiusd/fast_profiles', { params }).then(response => {
      return response.data
    })
  },
  radiusFastsOptions: () => {
    return apiCall.options('config/radiusd/fast_profiles').then(response => {
      return response.data
    })
  },
  radiusFast: id => {
    return apiCall.get(['config', 'radiusd', 'fast_profile', id]).then(response => {
      return response.data.item
    })
  },
  radiusFastOptions: id => {
    return apiCall.options(['config', 'radiusd', 'fast_profile', id]).then(response => {
      return response.data
    })
  },
  createRadiusFast: data => {
    return apiCall.post('config/radiusd/fast_profiles', data).then(response => {
      return response.data
    })
  },
  updateRadiusFast: data => {
    return apiCall.patch(['config', 'radiusd', 'fast_profile', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRadiusFast: id => {
    return apiCall.delete(['config', 'radiusd', 'fast_profile', id])
  }
}
