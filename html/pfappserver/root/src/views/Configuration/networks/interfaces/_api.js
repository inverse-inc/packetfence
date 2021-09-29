import apiCall from '@/utils/api'

export default {
  interfaces: params => {
    return apiCall.get('config/interfaces', { params }).then(response => {
      return response.data
    })
  },
  interface: id => {
    return apiCall.get(['config', 'interface', id]).then(response => {
      return response.data.item
    })
  },
  createInterface: data => {
    let sanitizedData = {}
    Object.keys(data).forEach(key => {
      if (typeof data[key] !== 'boolean') {
        sanitizedData[key] = data[key]
      }
    })
    return apiCall.post('config/interfaces', sanitizedData).then(response => {
      return response.data
    })
  },
  updateInterface: data => {
    return apiCall.patch(['config', 'interface', data.id], data).then(response => {
      return response.data
    })
  },
  downInterface: id => {
    return apiCall.postQuiet(['config', 'interface', id, 'down']).then(response => {
      return response.data
    })
  },
  upInterface: id => {
    return apiCall.postQuiet(['config', 'interface', id, 'up']).then(response => {
      return response.data
    })
  },
  deleteInterface: id => {
    return apiCall.delete(['config', 'interface', id])
  }
}
