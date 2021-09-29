import store from '@/store'
import DomainsStoreModule from '../domains/_store'
import RealmsStoreModule from './_store'
import TenantsStoreModule from '../tenants/_store'

export const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/TheTabsDomains')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: params => $router.push({ name: 'realms', params }),
    goToItem: params => $router
      .push({ name: 'realm', params: { ...params, tenantId: params.tenantId.toString() } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneRealm', params: { ...params, tenantId: params.tenantId.toString() } }),
    goToNew: params => $router.push({ name: 'newRealm', params: { ...params, tenantId: params.tenantId.toString() } })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_domains)
    store.registerModule('$_domains', DomainsStoreModule)
  if (!store.state.$_realms)
    store.registerModule('$_realms', RealmsStoreModule)
  if (!store.state.$_tenants)
    store.registerModule('$_tenants', TenantsStoreModule)
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
    path: 'realms/:tenantId/new',
    name: 'newRealm',
    component: TheView,
    props: (route) => ({ isNew: true, tenantId: route.params.tenantId }),
    beforeEnter
  },
  {
    path: 'realm/:tenantId/:id',
    name: 'realm',
    component: TheView,
    props: (route) => ({ tenantId: route.params.tenantId, id: route.params.id }),
    beforeEnter: (to, from, next) => {
        beforeEnter()
      store.dispatch('$_realms/getRealm', { id: to.params.id, tenantId: to.params.tenantId }).then(() => {
        next()
      })
    }
  },
  {
    path: 'realm/:tenantId/:id/clone',
    name: 'cloneRealm',
    component: TheView,
    props: (route) => ({ tenantId: route.params.tenantId, id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
        beforeEnter()
      store.dispatch('$_realms/getRealm', { id: to.params.id, tenantId: to.params.tenantId }).then(() => {
        next()
      })
    }
  }
]
