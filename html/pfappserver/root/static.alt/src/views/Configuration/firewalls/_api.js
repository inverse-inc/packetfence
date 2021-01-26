import apiCall from '@/utils/api'

export default {
  firewalls: params => {
    return apiCall.get('config/firewalls', { params }).then(response => {
      return response.data
    })
  },
  firewallsOptions: firewallType => {
    return apiCall.options(['config', 'firewalls'], { params: { type: firewallType } }).then(response => {
      return response.data
    })
  },
  firewall: id => {
    return apiCall.get(['config', 'firewall', id]).then(response => {
      return response.data.item
    })
  },
  firewallOptions: id => {
    return apiCall.options(['config', 'firewall', id]).then(response => {
      return response.data
    })
  },
  createFirewall: data => {
    return apiCall.post('config/firewalls', data).then(response => {
      return response.data
    })
  },
  updateFirewall: data => {
    return apiCall.patch(['config', 'firewall', data.id], data).then(response => {
      return response.data
    })
  },
  deleteFirewall: id => {
    return apiCall.delete(['config', 'firewall', id])
  }
}
