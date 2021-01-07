import apiCall from '@/utils/api'

export default {
  wrixLocations: params => {
    return apiCall.get('wrix_locations', { params }).then(response => {
      return response.data
    })
  },
  wrixLocation: id => {
    return apiCall.get(['wrix_location', id]).then(response => {
      return response.data.item
    })
  },
  createWrixLocation: data => {
    return apiCall.post('wrix_locations', data).then(response => {
      return response.data
    })
  },
  updateWrixLocation: data => {
    return apiCall.patch(['wrix_location', data.id], data).then(response => {
      return response.data
    })
  },
  deleteWrixLocation: id => {
    return apiCall.delete(['wrix_location', id])
  }
}
