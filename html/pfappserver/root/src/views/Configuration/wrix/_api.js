import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('wrix_locations', { params }).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('wrix_locations/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('wrix_locations', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['wrix_location', id]).then(response => {
      return response.data.item
    })
  },
  update: data => {
    return apiCall.patch(['wrix_location', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['wrix_location', id])
  }
}
