import apiCall from '@/utils/api'

import GeneralSettingsApi from './generalSettings/_api'
import CombinationsApi from './combinations/_api'
import DevicesApi from './devices/_api'
import DhcpFingerprintsApi from './dhcpFingerprints/_api'
import Dhcpv6EnterprisesApi from './dhcpv6Enterprises/_api'
import Dhcpv6FingerprintsApi from './dhcpv6Fingerprints/_api'
import DhcpVendorsApi from './dhcpVendors/_api'
import MacVendorsApi from './macVendors/_api'
import UserAgentsApi from './userAgents/_api'

export default {
  ...GeneralSettingsApi,
  ...CombinationsApi,
  ...DevicesApi,
  ...DhcpFingerprintsApi,
  ...Dhcpv6EnterprisesApi,
  ...Dhcpv6FingerprintsApi,
  ...DhcpVendorsApi,
  ...MacVendorsApi,
  ...UserAgentsApi,

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
