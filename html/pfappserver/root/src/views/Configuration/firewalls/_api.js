import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/firewalls', { params }).then(response => {
      return response.data
    })
  },
  listOptions: firewallType => {
    return apiCall.options(['config', 'firewalls'], { params: { type: firewallType } }).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/firewalls/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/firewalls', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'firewall', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'firewall', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'firewall', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'firewall', id])
  }
}
