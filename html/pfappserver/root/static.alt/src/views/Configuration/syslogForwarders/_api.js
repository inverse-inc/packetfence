import apiCall from '@/utils/api'

export default {
  syslogForwarders: params => {
    return apiCall.get('config/syslog_forwarders', { params }).then(response => {
      return response.data
    })
  },
  syslogForwardersOptions: syslogForwarderType => {
    return apiCall.options(['config', 'syslog_forwarders'], { params: { type: syslogForwarderType } }).then(response => {
      return response.data
    })
  },
  syslogForwarder: id => {
    return apiCall.get(['config', 'syslog_forwarder', id]).then(response => {
      return response.data.item
    })
  },
  syslogForwarderOptions: id => {
    return apiCall.options(['config', 'syslog_forwarder', id]).then(response => {
      return response.data
    })
  },
  createSyslogForwarder: data => {
    return apiCall.post('config/syslog_forwarders', data).then(response => {
      return response.data
    })
  },
  updateSyslogForwarder: data => {
    return apiCall.patch(['config', 'syslog_forwarder', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSyslogForwarder: id => {
    return apiCall.delete(['config', 'syslog_forwarder', id])
  }
}
