import store from '@/store'
import BasesStoreModule from '@/views/Configuration/bases/_store'
import FingerbankStoreModule from '@/views/Configuration/fingerbank/_store'
import FingerbankCommunicationStoreModule from './_store'

const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

export default [
  {
    path: 'network_communication',
    name: 'statusNetworkCommunication',
    component: TheView,
    meta: {
      can: 'read nodes'
    },
    beforeEnter: (to, from, next) => {
      if (!store.state.$_bases)
        store.registerModule('$_bases', BasesStoreModule)
      if (!store.state.$_fingerbank)
        store.registerModule('$_fingerbank', FingerbankStoreModule)
      if (!store.state.$_fingerbank_communication)
        store.registerModule('$_fingerbank_communication', FingerbankCommunicationStoreModule)
      Promise.all([
        store.dispatch('$_bases/getGeneral'),
        store.dispatch('$_fingerbank/getClasses')
      ]).then(() => next())
    },
  }
]
