import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/dns_connectors', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/dns_connectors').then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/dns_connectors/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/dns_connectors', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'dns_connector', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'dns_connector', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'dns_connector', data.id], data).then(response => {
      return response.data
    })
  },
  sort: data => {
    return apiCall.patch('config/dns_connectors/sort_items', data).then(response => {
      return response
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'dns_connector', id])
  },

  lookup: data => {
    return apiCall.post('pfconnector-remotes/dns-lookup', data).then(response => {
      return response.data
    })
  }
}
