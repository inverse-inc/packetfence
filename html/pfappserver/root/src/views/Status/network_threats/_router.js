import store from '@/store'
import FingerbankStoreModule from '@/views/Configuration/fingerbank/_store'
import SecurityEventsStoreModule from '@/views/Configuration/securityEvents/_store'
import NetworkThreatsStoreModule from './_store'
import NodesStoreModule from '@/views/Nodes/_store'

const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

export default [
  {
    path: 'network_threats',
    name: 'statusNetworkThreats',
    component: TheView,
    meta: {
      can: 'read nodes'
    },
    beforeEnter: (to, from, next) => {
      if (!store.state.$_fingerbank)
        store.registerModule('$_fingerbank', FingerbankStoreModule)
      if (!store.state.$_security_events)
        store.registerModule('$_security_events', SecurityEventsStoreModule)
      if (!store.state.$_network_threats)
        store.registerModule('$_network_threats', NetworkThreatsStoreModule)
      if (!store.state.$_nodes)
        store.registerModule('$_nodes', NodesStoreModule)
      Promise.all([
        store.dispatch('$_fingerbank/getClasses'),
        store.dispatch('$_network_threats/stat'),
        store.dispatch('$_nodes/getPerDeviceClass')
      ]).finally(() => next())
    }
  }
]