import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('config/template_switches', { params }).then(response => {
      return response.data
    })
  },
  listOptions: () => {
    return apiCall.options('config/template_switches').then(response => {
      return response.data
    })
  },
  search: data => {
    return apiCall.post('config/template_switches/search', data).then(response => {
      return response.data
    })
  },
  create: data => {
    return apiCall.post('config/template_switches', data).then(response => {
      return response.data
    })
  },

  item: id => {
    return apiCall.get(['config', 'template_switch', id]).then(response => {
      return response.data.item
    })
  },
  update: data => {
    return apiCall.patch(['config', 'template_switch', data.id], data).then(response => {
      return response.data
    })
  },
  delete: id => {
    return apiCall.delete(['config', 'template_switch', id])
  }
}
