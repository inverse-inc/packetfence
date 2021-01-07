import apiCall from '@/utils/api'

export default {
  fingerbankGeneralSettings: params => {
    return apiCall.get(['config', 'fingerbank_settings'], { params }).then(response => {
      return response.data.items
    })
  },
  fingerbankGeneralSettingsOptions: () => {
    return apiCall.options('config/fingerbank_settings').then(response => {
      return response.data
    })
  },
  fingerbankUpdateGeneralSetting: (id, params) => {
    const patch = params.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'fingerbank_setting', id], params).then(response => {
      return response.data
    })
  }
}
