import apiCall from '@/utils/api'

export default {
  mfas: params => {
    return apiCall.get('config/mfas', { params }).then(response => {
      return response.data
    })
  },
  mfasOptions: mfaType => {
    return apiCall.options(['config', 'mfas'], { params: { type: mfaType } }).then(response => {
      return response.data
    })
  },
  mfa: id => {
    return apiCall.get(['config', 'mfa', id]).then(response => {
      return response.data.item
    })
  },
  mfaOptions: id => {
    return apiCall.options(['config', 'mfa', id]).then(response => {
      return response.data
    })
  },
  createMfa: data => {
    return apiCall.post('config/mfas', data).then(response => {
      return response.data
    })
  },
  updateMfa: data => {
    return apiCall.patch(['config', 'mfa', data.id], data).then(response => {
      return response.data
    })
  },
  deleteMfa: id => {
    return apiCall.delete(['config', 'mfa', id])
  }
}
