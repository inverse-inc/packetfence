import apiCall from '@/utils/api'

export default {
  securityEvents: params => {
    return apiCall.get('config/security_events', { params }).then(response => {
      return response.data
    })
  },
  securityEventsOptions: () => {
    return apiCall.options('config/security_events').then(response => {
      return response.data
    })
  },
  securityEvent: id => {
    return apiCall.get(['config', 'security_event', id]).then(response => {
      return response.data.item
    })
  },
  securityEventOptions: id => {
    return apiCall.options(['config', 'security_event', id]).then(response => {
      return response.data
    })
  },
  createSecurityEvent: data => {
    return apiCall.post('config/security_events', data).then(response => {
      return response.data
    })
  },
  updateSecurityEvent: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'security_event', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSecurityEvent: id => {
    return apiCall.delete(['config', 'security_event', id])
  }
}
