import apiCall from '@/utils/api'

export default {
  clouds: params => {
    return apiCall.get('config/clouds', { params }).then(response => {
      return response.data
    })
  },
  cloudsOptions: cloudType => {
    return apiCall.options(['config', 'clouds'], { params: { type: cloudType } }).then(response => {
      return response.data
    })
  },
  cloud: id => {
    return apiCall.get(['config', 'cloud', id]).then(response => {
      return response.data.item
    })
  },
  cloudOptions: id => {
    return apiCall.options(['config', 'cloud', id]).then(response => {
      return response.data
    })
  },
  createCloud: data => {
    return apiCall.post('config/clouds', data).then(response => {
      return response.data
    })
  },
  updateCloud: data => {
    return apiCall.patch(['config', 'cloud', data.id], data).then(response => {
      return response.data
    })
  },
  deleteCloud: id => {
    return apiCall.delete(['config', 'cloud', id])
  }
}
