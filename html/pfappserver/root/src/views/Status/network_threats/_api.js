import apiCall from '@/utils/api'

export default {
  search: data => {
    return apiCall.post('security_events/search', data).then(response => {
      return response.data
    })
  },
  totalOpen: () => {
    return apiCall.get('security_events/total_open').then(response => {
      return response.data
    })
  },
  totalClosed: () => {
    return apiCall.get('security_events/total_closed').then(response => {
      return response.data
    })
  },
  perDeviceClassOpen: () => {
    return apiCall.get('security_events/per_device_class_open').then(response => {
      return response.data
    })
  },
  perDeviceClassClosed: () => {
    return apiCall.get('security_events/per_device_class_closed').then(response => {
      return response.data
    })
  },
  perSecurityEventOpen: () => {
    return apiCall.get('security_events/per_security_event_id_open').then(response => {
      return response.data
    })
  },
  perSecurityEventClosed: () => {
    return apiCall.get('security_events/per_security_event_id_closed').then(response => {
      return response.data
    })
  },
}



