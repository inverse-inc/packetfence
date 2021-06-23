import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get(['config', 'scans'], { params }).then(response => {
      return response.data
    })
  },
  listOptions: scanType => {
    return apiCall.options(['config', 'scans'], { params: { type: scanType } }).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/scans/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/scans', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'scan', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'scan', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'scan', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'scan', id])
  }
}
