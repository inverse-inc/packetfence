import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/event_handlers', { params }).then(response => {
      return response.data
    })
  },
  listOptions: eventHandlerType => {
    return apiCall.options(['config', 'event_handlers'], { params: { type: eventHandlerType } }).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/event_handlers/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/event_handlers', data).then(response => {
      return response.data
    })
  },
  dryRunItem: data => {
    return apiCall.post('config/event_handlers/dry_run', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'event_handler', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'event_handler', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'event_handler', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'event_handler', id])
  }
}
