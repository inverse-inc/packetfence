import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/ssl_certificates', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/ssl_certificates').then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/ssl_certificates/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/ssl_certificates', data).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'ssl_certificate', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'ssl_certificate', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'ssl_certificate', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'ssl_certificate', id])
  }
}
