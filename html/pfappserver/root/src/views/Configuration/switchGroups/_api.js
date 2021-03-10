import apiCall from '@/utils/api'

export default {
  switchGroups: params => {
    return apiCall.get(['config', 'switch_groups'], { params: { ...params, raw: 1 } }).then(response => {
      return response.data
    })
  },
  switchGroupsOptions: () => {
    return apiCall.options('config/switch_groups').then(response => {
      return response.data
    })
  },
  switchGroup: id => {
    return apiCall.get(['config', 'switch_group', id], { params: { skip_inheritance: true } }).then(response => {
      return response.data.item
    })
  },
  switchGroupMembers: id => {
    return apiCall.get(['config', 'switch_group', id, 'members']).then(response => {
      return response.data.items
    })
  },
  switchGroupOptions: id => {
    return apiCall.options(['config', 'switch_group', id]).then(response => {
      return response.data
    })
  },
  createSwitchGroup: data => {
    return apiCall.post('config/switch_groups', data).then(response => {
      return response.data
    })
  },
  updateSwitchGroup: data => {
    return apiCall.patch(['config', 'switch_group', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSwitchGroup: id => {
    return apiCall.delete(['config', 'switch_group', id])
  }
}
