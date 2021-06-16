import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/syslog_parsers', { params }).then(response => {
      return response.data
    })
  },
  listOptions: syslogParserType => {
    return apiCall.options(['config', 'syslog_parsers'], { params: { type: syslogParserType } }).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/syslog_parsers/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/syslog_parsers', data).then(response => {
      return response.data
    })
  },
  dryRunItem: data => {
    return apiCall.post('config/syslog_parsers/dry_run', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'syslog_parser', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'syslog_parser', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'syslog_parser', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'syslog_parser', id])
  }
}
