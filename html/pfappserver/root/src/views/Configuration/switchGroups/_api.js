import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get(['config', 'switch_groups'], { params: { ...params, raw: 1 } }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/switch_groups').then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/switch_groups/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/switch_groups', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'switch_group', id], { params: { skip_inheritance: true } }).then(response => {
      return response.data.item
    })
  },
  itemMembers: id => {
    return apiCall.get(['config', 'switch_group', id, 'members']).then(response => {
      return response.data.items
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'switch_group', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'switch_group', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'switch_group', id])
  }
}
