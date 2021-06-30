import apiCall from '@/utils/api'

export default {
  create: body => {
    return apiCall.post('logs/tail', body).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['logs', 'tail', id ]).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.getQuiet(`logs/tail/${id}`, { performance: false }).then(response => {
      return response.data
    })
  },
  options: () => {
    return apiCall.options('logs/tail').then(response => {
      return response.data
    })
  },
  touch: id => {
    return apiCall.postQuiet(['logs', 'tail', id, 'touch']).then(response => {
      return response.data
    })
  }
}
