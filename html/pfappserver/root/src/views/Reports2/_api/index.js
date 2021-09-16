import apiCall from '@/utils/api'

export default {
  list: params => {
    if (params.sort)
      params.sort = params.sort.join(',')
    else
      params.sort = 'id'
    if (params.fields && params.fields.constructor === Array)
      params.fields = params.fields.join(',')
    return apiCall.get('dynamic_reports', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('dynamic_reports').then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['dynamic_report', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['dynamic_report', id]).then(response => {
      return response.data
    })
  },
  search: body => {
    if (body.id) {
      return apiCall.post(['dynamic_report', body.id, 'search'], body).then(response => {
        return response.data
      })
    }
    else {
      return new Promise(r => r({ items: [] }))
    }
  }
}
