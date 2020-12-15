import store from '@/store'
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
    props: (route) => ({ tab: 'network', query: route.query.query })
  },
  {
    path: 'network',
    name: 'network',
    component: TheTabs,
    props: (route) => ({ tab: 'network', query: route.query.query })
  },
  {
    path: 'inline',
    name: 'inline',
    component: TheTabs,
    props: (route) => ({ tab: 'inline', query: route.query.query })
  },
  {
    path: 'fencing',
    name: 'fencing',
    component: TheTabs,
    props: (route) => ({ tab: 'fencing', query: route.query.query })
  },
  {
    path: 'parking',
    name: 'parking',
    component: TheTabs,
    props: (route) => ({ tab: 'parking', query: route.query.query })
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
