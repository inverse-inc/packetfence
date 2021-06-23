import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.getQuiet('pki/revokedcerts', { params }).then(response => {
      const { data: { items = [] } = {} } = response
      return { items }
    })
  },
  search: params => {
    return apiCall.postQuiet('pki/revokedcerts/search', params).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['pki', 'revokedcert', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return item
    })
  }
}
