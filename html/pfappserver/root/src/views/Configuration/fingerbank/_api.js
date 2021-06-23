import apiCall from '@/utils/api'

export default {
  fingerbankAccountInfo: () => {
    return apiCall.getQuiet(['fingerbank', 'account_info']).then(response => {
      return response.data
    })
  },
  fingerbankCanUseNbaEndpoints: () => {
    return apiCall.getQuiet(['fingerbank', 'can_use_nba_endpoints']).then(response => {
      return response.data
    })
  },
  fingerbankUpdateDatabase: () => {
    return apiCall.post(['fingerbank', 'update_upstream_db'], {}).then(response => {
      return response.data
    })
  }
}
