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
    goToCollection: () => $router.push({ name: 'connectorsConnectors' }),
    goToItem: params => $router
      .push({ name: 'connectorsConnector', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneConnectorsConnector', params }),
    goToNew: params => $router.push({ name: 'newConnectorsConnector', params })
  }
}


export default [
  {
    path: 'connectors/connectors',
    name: 'connectorsConnectors',
    component: TheTabs,
    props: () => ({ tab: 'connectorsConnectors' }),
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
