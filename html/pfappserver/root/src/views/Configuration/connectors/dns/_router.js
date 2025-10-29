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
    goToCollection: () => $router.push({ name: 'connectorsDns' }),
    goToItem: params => $router
      .push({ name: 'connectorsDn', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneConnectorsDn', params }),
    goToNew: params => $router.push({ name: 'newConnectorsDn', params })
  }
}


export default [
  {
    path: 'connectors/dns',
    name: 'connectorsDns',
    component: TheTabs,
    props: () => ({ tab: 'connectorsDns' }),
    beforeEnter
  },
  {
    path: 'connectors/dns/new',
    name: 'newConnectorsDn',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'connectors/dn/:id',
    name: 'connectorsDn',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_connectors/getDn', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'connectors/dn/:id/clone',
    name: 'cloneConnectorsDn',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_connectors/getDn', to.params.id).then(() => {
        next()
      })
    }
  }
]
