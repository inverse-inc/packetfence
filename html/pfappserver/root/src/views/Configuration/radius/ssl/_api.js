import apiCall from '@/utils/api'

export default {
  radiusSsls: params => {
    return apiCall.get('config/ssl_certificates', { params }).then(response => {
      return response.data
    })
  },
  radiusSslsOptions: () => {
    return apiCall.options('config/ssl_certificates').then(response => {
      return response.data
    })
  },
  radiusSsl: id => {
    return apiCall.get(['config', 'ssl_certificate', id]).then(response => {
      return response.data.item
    })
  },
  radiusSslOptions: id => {
    return apiCall.options(['config', 'ssl_certificate', id]).then(response => {
      return response.data
    })
  },
  createRadiusSsl: data => {
    return apiCall.post('config/ssl_certificates', data).then(response => {
      return response.data
    })
  },
  updateRadiusSsl: data => {
    return apiCall.patch(['config', 'ssl_certificate', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRadiusSsl: id => {
    return apiCall.delete(['config', 'ssl_certificate', id])
  }
}
