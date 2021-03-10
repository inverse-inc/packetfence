import apiCall from '@/utils/api'

export default {
  pkiCas: () => {
    return apiCall.get('pki/cas').then(response => {
      const { data: { items = [] } = {} } = response
      return { items }
    })
  },
  pkiCa: id => {
    return apiCall.get(['pki', 'ca', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return item
    })
  },
  createPkiCa: data => {
    return apiCall.post('pki/cas', data).then(response => {
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
