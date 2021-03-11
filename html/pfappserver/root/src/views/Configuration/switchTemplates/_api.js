import apiCall from '@/utils/api'

export default {
  switchTemplates: params => {
    return apiCall.get('config/template_switches', { params }).then(response => {
      return response.data
    })
  },
  switchTemplatesOptions: () => {
    return apiCall.options('config/template_switches').then(response => {
      return response.data
    })
  },
  switchTemplate: id => {
    return apiCall.get(['config', 'template_switch', id]).then(response => {
      return response.data.item
    })
  },
  createSwitchTemplate: data => {
    return apiCall.post('config/template_switches', data).then(response => {
      return response.data
    })
  },
  updateSwitchTemplate: data => {
    return apiCall.patch(['config', 'template_switch', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSwitchTemplate: id => {
    return apiCall.delete(['config', 'template_switch', id])
  }
}
