import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get(['fingerbank', 'local', 'combinations'], { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('fingerbank/local/combinations/search', body).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['fingerbank', 'local', 'combination', id]).then(response => {
      return response.data.item
    })
  },
  create: data => {
    return apiCall.post('fingerbank/local/combinations', data).then(response => {
      return response.data
    })
  },
  update: data => {
    Object.keys(data).forEach(key => {
      if (/^not_/.test(key)) { // remove fields starting with 'not_'
        delete data[key]
      }
    })
    return apiCall.patch(['fingerbank', 'local', 'combination', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['fingerbank', 'local', 'combination', id])
  }
}

