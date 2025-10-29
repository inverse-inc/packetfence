import store from '@/store'
import StoreModule from '../_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../../_components/TheTabsConnectors')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_connectors)
    store.registerModule('$_connectors', StoreModule)
  next()
}

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'connectorsDomains' }),
    goToItem: params => $router
      .push({ name: 'connectorsDomain', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneConnectorsDomain', params }),
    goToNew: params => $router.push({ name: 'newConnectorsDomain', params })
  }
}


export default [
  {
    path: 'connectors/domains',
    name: 'connectorsDomains',
    component: TheTabs,
    props: () => ({ tab: 'connectorsDomains' }),
    beforeEnter
  },
  {
    path: 'connectors/domains/new',
    name: 'newConnectorsDomain',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'connectors/domain/:id',
    name: 'connectorsDomain',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_connectors/getDomain', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'connectors/domain/:id/clone',
    name: 'cloneConnectorsDomain',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_connectors/getDomain', to.params.id).then(() => {
        next()
      })
    }
  }
]
