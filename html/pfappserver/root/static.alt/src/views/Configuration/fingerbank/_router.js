import store from '@/store'
import StoreModule from './_store'
import GeneralSettingsRoutes from './generalSettings/_router'
import DeviceChangeDetectionRoutes from './deviceChangeDetection/_router'
import CombinationsRoutes from './combinations/_router'
import DevicesRoutes from './devices/_router'
import DhcpFingerprintsRoutes from './dhcpFingerprints/_router'
import Dhcpv6EnterprisesRoutes from './dhcpv6Enterprises/_router'
import Dhcpv6FingerprintsRoutes from './dhcpv6Fingerprints/_router'
import DhcpVendorsRoutes from './dhcpVendors/_router'
import MacVendorsRoutes from './macVendors/_router'
import UserAgentsRoutes from './userAgents/_router'

const routes = [
  ...GeneralSettingsRoutes,
  ...DeviceChangeDetectionRoutes,
  ...CombinationsRoutes,
  ...DevicesRoutes,
  ...DhcpFingerprintsRoutes,
  ...Dhcpv6EnterprisesRoutes,
  ...Dhcpv6FingerprintsRoutes,
  ...DhcpVendorsRoutes,
  ...MacVendorsRoutes,
  ...UserAgentsRoutes
]

const routesWithStore = routes.map(route => {
  const { beforeEnter, ...rest } = route || {}
  return { ...rest, beforeEnter: (to, from, next) => {
    // register store module on all routes
    if (!store.state.$_fingerbank)
      store.registerModule('$_fingerbank', StoreModule)
    if (beforeEnter)
      beforeEnter(to, from, next)
    else
      next()
  } }
})

export default routesWithStore
