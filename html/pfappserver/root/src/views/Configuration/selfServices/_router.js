import store from '@/store'
import StoreModule from './_store'

const TheSearch = () => import(/* webpackChunkName: "Configuration" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'self_services' }),
    goToItem: params => $router
      .push({ name: 'self_service', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneSelfService', params }),
    goToNew: params => $router.push({ name: 'newSelfService', params })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_self_services)
    store.registerModule('$_self_services', StoreModule)
  next()
}

export default [
  {
    path: 'self_services',
    name: 'self_services',
    component: TheSearch,
    beforeEnter
  },
  {
    path: 'self_services/new',
    name: 'newSelfService',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'self_service/:id',
    name: 'self_service',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_self_services/getSelfService', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'self_service/:id/clone',
    name: 'cloneSelfService',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_self_services/getSelfService', to.params.id).then(() => {
        next()
      })
    }
  }
]
