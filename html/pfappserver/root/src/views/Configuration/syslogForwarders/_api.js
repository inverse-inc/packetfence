import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/syslog_forwarders', { params }).then(response => {
      return response.data
    })
  },
  listOptions: syslogForwarderType => {
    return apiCall.options(['config', 'syslog_forwarders'], { params: { type: syslogForwarderType } }).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/syslog_forwarders/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/syslog_forwarders', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'syslog_forwarder', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'syslog_forwarder', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'syslog_forwarder', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'syslog_forwarder', id])
  }
}
