import { toRefs } from '@vue/composition-api'
import store from '@/store'
import DomainsStoreModule from '../domains/_store'
import RealmsStoreModule from './_store'

export const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/DomainsTabs')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: (params, props) => {
      const { tenantId } = toRefs(props)
      return $router.push({ name: 'realms', params: { tenantId: tenantId.value } })
    },
    goToItem: (params, props) => {
      const { tenantId } = toRefs(props)
      return $router
        .push({ name: 'realm', params: { ...params, tenantId: tenantId.value } })
        .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
    },
    goToClone: (params, props) => {
      const { tenantId } = toRefs(props)
      return $router.push({ name: 'cloneRealm', params: { ...params, tenantId: tenantId.value } })
    }
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
    props: (route) => ({ tab: 'realms', query: route.query.query }),
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
