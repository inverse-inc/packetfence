import apiCall from '@/utils/api'
const baseURL = '/api/v1.1'

export default {
  list: params => {
    if (params.sort)
      params.sort = params.sort.join(',')
    else
      params.sort = 'id'
    if (params.fields && params.fields.constructor === Array)
      params.fields = params.fields.join(',')
    return apiCall.get('reports', { baseURL, params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('reports', { baseURL }).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['report', id], { baseURL }).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['report', id], { baseURL }).then(response => {
      return response.data
    })
  },
  search: body => {
    if (body.id) {
      return apiCall.post(['report', body.id, 'search'], body, { baseURL }).then(response => {
        return response.data
      })
    }
    else {
      return new Promise(r => r({ items: [] }))
    }
  }
}
