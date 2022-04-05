import store from '@/store'
import StoreModule from './_store'

const TheSearch = () => import(/* webpackChunkName: "Configuration" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'connectors' }),
    goToItem: params => $router
      .push({ name: 'connector', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneConnector', params }),
    goToNew: params => $router.push({ name: 'newConnector', params })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_connectors)
    store.registerModule('$_connectors', StoreModule)
  next()
}

export default [
  {
    path: 'connectors',
    name: 'connectors',
    component: TheSearch,
    beforeEnter
  },
  {
    path: 'connectors/new',
    name: 'newConnector',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'connector/:id',
    name: 'connector',
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
    path: 'connector/:id/clone',
    name: 'cloneConnector',
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
