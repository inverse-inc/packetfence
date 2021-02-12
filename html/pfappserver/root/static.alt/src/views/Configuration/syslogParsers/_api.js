import apiCall from '@/utils/api'

export default {
  syslogParsers: params => {
    return apiCall.get('config/syslog_parsers', { params }).then(response => {
      return response.data
    })
  },
  syslogParsersOptions: syslogParserType => {
    return apiCall.options(['config', 'syslog_parsers'], { params: { type: syslogParserType } }).then(response => {
      return response.data
    })
  },
  syslogParser: id => {
    return apiCall.get(['config', 'syslog_parser', id]).then(response => {
      return response.data.item
    })
  },
  syslogParserOptions: id => {
    return apiCall.options(['config', 'syslog_parser', id]).then(response => {
      return response.data
    })
  },
  createSyslogParser: data => {
    return apiCall.post('config/syslog_parsers', data).then(response => {
      return response.data
    })
  },
  updateSyslogParser: data => {
    return apiCall.patch(['config', 'syslog_parser', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSyslogParser: id => {
    return apiCall.delete(['config', 'syslog_parser', id])
  },
  dryRunSyslogParser: data => {
    return apiCall.post('config/syslog_parsers/dry_run', data).then(response => {
      return response.data
    })
  }
}
