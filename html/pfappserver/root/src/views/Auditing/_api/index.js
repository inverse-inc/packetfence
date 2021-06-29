import apiCall from '@/utils/api'

export default {
  createLogTailSession: body => {
    return apiCall.post('logs/tail', body).then(response => {
      return response.data
    })
  },
  deleteLogTailSession: id => {
    return apiCall.delete(['logs', 'tail', id ]).then(response => {
      return response.data
    })
  },
  getLogTailSession: id => {
    return apiCall.getQuiet(`logs/tail/${id}`, { performance: false }).then(response => {
      return response.data
    })
  },
  optionsLogTailSession: () => {
    return apiCall.options('logs/tail').then(response => {
      return response.data
    })
  },
  touchLogTailSession: id => {
    return apiCall.postQuiet(['logs', 'tail', id, 'touch']).then(response => {
      return response.data
    })
  }
}
