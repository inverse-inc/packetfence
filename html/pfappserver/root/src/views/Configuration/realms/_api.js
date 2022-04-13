import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/realms', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/realms').then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/realms/search', data).then(response => {
      return response.data
    })
  },
  sortItems: items => {
    return apiCall.patch('config/realms/sort_items', items).then(response => {
      return response
    })
  },
  create: item => {
    return apiCall.post('config/realms', item).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'realm', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'realm', id]).then(response => {
      return response.data
    })
  },
  update: item => {
    return apiCall.patch(['config', 'realm', item.id], item).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'realm', id])
  }
}
