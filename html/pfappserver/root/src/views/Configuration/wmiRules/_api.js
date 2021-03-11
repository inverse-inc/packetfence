import apiCall from '@/utils/api'

export default {
  wmiRules: params => {
    return apiCall.get('config/wmi_rules', { params }).then(response => {
      return response.data
    })
  },
  wmiRulesOptions: () => {
    return apiCall.options('config/wmi_rules').then(response => {
      return response.data
    })
  },
  wmiRule: id => {
    return apiCall.get(['config', 'wmi_rule', id]).then(response => {
      return response.data.item
    })
  },
  wmiRuleOptions: id => {
    return apiCall.options(['config', 'wmi_rule', id]).then(response => {
      return response.data
    })
  },
  createWmiRule: data => {
    return apiCall.post('config/wmi_rules', data).then(response => {
      return response.data
    })
  },
  updateWmiRule: data => {
    return apiCall.patch(['config', 'wmi_rule', data.id], data).then(response => {
      return response.data
    })
  },
  deleteWmiRule: id => {
    return apiCall.delete(['config', 'wmi_rule', id])
  }
}
