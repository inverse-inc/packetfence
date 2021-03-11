import apiCall from '@/utils/api'

export default {
  pkiProfiles: () => {
    return apiCall.get('pki/profiles').then(response => {
      const { data: { items = [] } = {} } = response
      return { items }
    })
  },
  pkiProfile: id => {
    return apiCall.get(['pki', 'profile', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return item
    })
  },
  createPkiProfile: data => {
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
  updatePkiProfile: data => {
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
