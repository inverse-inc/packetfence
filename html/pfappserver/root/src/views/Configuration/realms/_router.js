import store from '@/store'
import DomainsStoreModule from '../domains/_store'
import RealmsStoreModule from './_store'

export const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/TheTabsDomains')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: params => $router.push({ name: 'realms', params }),
    goToItem: params => $router
      .push({ name: 'realm', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneRealm', params }),
    goToNew: params => $router.push({ name: 'newRealm', params })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_domains)
    store.registerModule('$_domains', DomainsStoreModule)
  if (!store.state.$_realms)
    store.registerModule('$_realms', RealmsStoreModule)
  next()
}

export default [
  {
    path: 'realms',
    name: 'realms',
    component: TheTabs,
    props: () => ({ tab: 'realms' }),
    beforeEnter
  },
  {
    path: 'realms/new',
    name: 'newRealm',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'realm/:id',
    name: 'realm',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_realms/getRealm', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'realm/:id/clone',
    name: 'cloneRealm',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_realms/getRealm', to.params.id).then(() => {
        next()
      })
    }
  }
]
