import store from '@/store'
import StoreModule from '../_store'
import FingerbankStoreModule from '../../fingerbank/_store'

const TheSearch = () => import(/* webpackChunkName: "ConfigurationNetwork" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "ConfigurationNetwork" */ './_components/TheView')
const TheTopology = () => import(/* webpackChunkName: "ConfigurationNetwork" */ './_components/TheTopology')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_connectors)
    store.registerModule('$_connectors', StoreModule)
  if (!store.state.$_fingerbank)
    store.registerModule('$_fingerbank', FingerbankStoreModule)
  store.dispatch('$_fingerbank/getGeneralSettings').then(() => {
    next()
  })
}

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'connectorsConnectors' }),
    goToItem: params => $router
      .push({ name: 'connectorsConnector', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneConnectorsConnector', params }),
    goToNew: params => $router.push({ name: 'newConnectorsConnector', params }),
    goToTopology: () => $router.push({ name: 'connectorsTopology' })
  }
}


export default [
  // Historical path of the list, kept for existing links; same page as
  // the 'connectors' section route.
  {
    path: 'connectors/connectors',
    name: 'connectorsConnectors',
    component: TheSearch,
    beforeEnter
  },
  {
    path: 'connectors/topology',
    name: 'connectorsTopology',
    component: TheTopology,
    beforeEnter
  },
  {
    path: 'connectors/connectors/new',
    name: 'newConnectorsConnector',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'connectors/connector/:id',
    name: 'connectorsConnector',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_connectors/getConnector', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'connectors/connector/:id/clone',
    name: 'cloneConnectorsConnector',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_connectors/getConnector', to.params.id).then(() => {
        next()
      })
    }
  }
]
