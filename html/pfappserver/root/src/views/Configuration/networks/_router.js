import store from '@/store'
import BasesStoreModule from '../bases/_store'
import RolesStoreModule from '../roles/_store'
import InterfacesStoreModule from './interfaces/_store'
import Layer2NetworksStoreModule from './layer2Networks/_store'
import RoutedNetworksStoreModule from './routedNetworks/_store'
import TrafficShapingPoliciesStoreModule from './trafficShapingPolicies/_store'

import InterfacesRoutes from './interfaces/_router'
import Layer2NetworksRoutes from './layer2Networks/_router'
import RoutedNetworksRoutes from './routedNetworks/_router'
import TrafficShapingPoliciesRoutes from './trafficShapingPolicies/_router'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/NetworksTabs')

const routes = [
  {
    path: 'networks',
    name: 'networks',
    component: TheTabs,
    props: () => ({ tab: 'network' })
  },
  {
    path: 'network',
    name: 'network',
    component: TheTabs,
    props: () => ({ tab: 'network' })
  },
  {
    path: 'inline',
    name: 'inline',
    component: TheTabs,
    props: () => ({ tab: 'inline' })
  },
  {
    path: 'fencing',
    name: 'fencing',
    component: TheTabs,
    props: () => ({ tab: 'fencing' })
  },
  {
    path: 'parking',
    name: 'parking',
    component: TheTabs,
    props: () => ({ tab: 'parking' })
  },

  ...InterfacesRoutes,
  ...Layer2NetworksRoutes,
  ...RoutedNetworksRoutes,
  ...TrafficShapingPoliciesRoutes
]

const routesWithStore = routes.map(route => {
  const { beforeEnter, ...rest } = route || {}
  return { ...rest, beforeEnter: (to, from, next) => {
    // register store modules on all routes
    if (!store.state.$_bases)
      store.registerModule('$_bases', BasesStoreModule)

    if (!store.state.$_roles)
      store.registerModule('$_roles', RolesStoreModule)

    if (!store.state.$_interfaces)
      store.registerModule('$_interfaces', InterfacesStoreModule)

    if (!store.state.$_layer2_networks)
      store.registerModule('$_layer2_networks', Layer2NetworksStoreModule)

    if (!store.state.$_routed_networks)
      store.registerModule('$_routed_networks', RoutedNetworksStoreModule)

    if (!store.state.$_traffic_shaping_policies)
      store.registerModule('$_traffic_shaping_policies', TrafficShapingPoliciesStoreModule)

    if (beforeEnter)
      beforeEnter(to, from, next)
    else
      next()
  } }
})

export default routesWithStore
