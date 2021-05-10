import store from '@/store'
import SecurityEventsStoreModule from './_store'
import ConnectionProfilesStoreModule from '../connectionProfiles/_store'
import NetworkBehaviorPoliciesStoreModule from '../networkBehaviorPolicy/_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/SecurityEventsList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'security_events' }),
    goToItem: params => $router
      .push({ name: 'security_event', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneSecurityEvent', params }),
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_security_events)
    store.registerModule('$_security_events', SecurityEventsStoreModule)
  if (!store.state.$_connection_profiles)
    store.registerModule('$_connection_profiles', ConnectionProfilesStoreModule)
  if (!store.state.$_network_behavior_policies)
    store.registerModule('$_network_behavior_policies', NetworkBehaviorPoliciesStoreModule)
  next()
}

export default [
  {
    path: 'security_events',
    name: 'security_events',
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter
  },
  {
    path: 'security_events/new',
    name: 'newSecurityEvent',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'security_event/:id',
    name: 'security_event',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_security_events/getSecurityEvent', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'security_event/:id/clone',
    name: 'cloneSecurityEvent',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_security_events/getSecurityEvent', to.params.id).then(() => {
        next()
      })
    }
  }
]
