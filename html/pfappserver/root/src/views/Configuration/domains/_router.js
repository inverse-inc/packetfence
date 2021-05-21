import store from '@/store'
import DomainsStoreModule from './_store'
import RealmsStoreModule from '../realms/_store'

export const useRouter = $router => {
  return {
    goToCollection: (params, props, autoJoinDomain) => {
      if (autoJoinDomain)
        $router.push({ name: 'domains', params: { autoJoinDomain: params } })
      else
        $router.push({ name: 'domains' })
    },
    goToItem: params => $router
      .push({ name: 'domain', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneDomain', params }),
    goToNew: () => $router.push({ name: 'newDomain' })
  }
}

export const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/DomainsTabs')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_domains)
    store.registerModule('$_domains', DomainsStoreModule)
  if (!store.state.$_realms)
    store.registerModule('$_realms', RealmsStoreModule)
  next()
}

export default [
  {
    path: 'domains',
    name: 'domains',
    component: TheTabs,
    props: (route) => ({ tab: 'domains', autoJoinDomain: route.params.autoJoinDomain }),
    beforeEnter
  },
  {
    path: 'domains/new',
    name: 'newDomain',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'domain/:id',
    name: 'domain',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_domains/getDomain', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'domain/:id/clone',
    name: 'cloneDomain',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_domains/getDomain', to.params.id).then(() => {
        next()
      })
    }
  }
]
