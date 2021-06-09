import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('pki/profiles', { params }).then(response => {
      const { data: { items = [] } = {} } = response
      return { items }
    })
  },
  search: params => {
    return apiCall.post('pki/profiles/search', params).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('pki/profiles', data).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return item
      }
    })
  },
  item: id => {
    return apiCall.get(['pki', 'profile', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return item
    })
  },
  update: data => {
    return apiCall.patch(['pki', 'profile', data.id], data).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return item
      }
    })
  }
}
