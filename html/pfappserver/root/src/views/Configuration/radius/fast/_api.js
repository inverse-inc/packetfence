import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/radiusd/fast_profiles', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/radiusd/fast_profiles').then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/radiusd/fast_profiles/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/radiusd/fast_profiles', data).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'radiusd', 'fast_profile', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'radiusd', 'fast_profile', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'radiusd', 'fast_profile', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'radiusd', 'fast_profile', id])
  }
}
