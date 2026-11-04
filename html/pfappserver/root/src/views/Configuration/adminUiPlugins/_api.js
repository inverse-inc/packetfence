import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/admin_ui_plugins', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/admin_ui_plugins').then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/admin_ui_plugins/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/admin_ui_plugins', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'admin_ui_plugin', id]).then(response => {
      return response.data.item
    })
  },
  itemOptions: id => {
    return apiCall.options(['config', 'admin_ui_plugin', id]).then(response => {
      return response.data
    })
  },
  update: data => {
    return apiCall.patch(['config', 'admin_ui_plugin', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'admin_ui_plugin', id])
  },
  // manifest served by the plugin, through the api-frontend proxy
  manifest: id => {
    return apiCall.get(['plugins', id, 'admin-ui']).then(response => {
      return response.data
    })
  }
}
