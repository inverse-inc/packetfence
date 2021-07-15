import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/event_loggers', { params }).then(response => {
      return response.data
    })
  },
  listOptions: eventLoggerType => {
    return apiCall.options(['config', 'event_loggers'], { params: { type: eventLoggerType } }).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/event_loggers/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/event_loggers', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'event_logger', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'event_logger', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'event_logger', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'event_logger', id])
  }
}
