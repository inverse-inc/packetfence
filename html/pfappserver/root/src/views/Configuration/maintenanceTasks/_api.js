import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/maintenance_tasks', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/maintenance_tasks').then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/maintenance_tasks', data).then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/maintenance_tasks/search', data).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(['config', 'maintenance_task', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'maintenance_task', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'maintenance_task', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'maintenance_task', id])
  }
}
