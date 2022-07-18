import store from '@/store'
import BasesStoreModule from '@/views/Configuration/bases/_store'
import FingerbankStoreModule from '@/views/Configuration/fingerbank/_store'
import FingerbankCommunicationStoreModule from './_store'
import NodesStoreModule from '@/views/Nodes/_store'

const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

const beforeEnter = (to, from, next) => {
  if (!store.state.$_bases)
    store.registerModule('$_bases', BasesStoreModule)
  if (!store.state.$_fingerbank)
    store.registerModule('$_fingerbank', FingerbankStoreModule)
  if (!store.state.$_fingerbank_communication)
    store.registerModule('$_fingerbank_communication', FingerbankCommunicationStoreModule)
  if (!store.state.$_nodes)
    store.registerModule('$_nodes', NodesStoreModule)
  Promise.all([
    store.dispatch('$_bases/getGeneral'),
    store.dispatch('$_fingerbank/getClasses'),
    store.dispatch('$_nodes/getPerDeviceClass')
  ]).then(() => next())
}

export default [
  {
    path: 'network_communication',
    name: 'statusNetworkCommunication',
    component: TheView,
    meta: {
      can: 'read nodes'
    },
    beforeEnter
  },
  {
    path: 'network_communication/:mac',
    name: 'statusNetworkCommunicationDevice',
    component: TheView,
    meta: {
      can: 'read nodes'
    },
    props: (route) => ({ device: route.params.mac }),
    beforeEnter
  }
]
