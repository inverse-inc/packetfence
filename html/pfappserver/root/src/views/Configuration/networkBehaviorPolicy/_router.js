import store from '@/store'
import FingerbankStoreModule from '../fingerbank/_store'
import NetworkBehaviorPolicyStoreModule from './_store'

const TheSearch = () => import(/* webpackChunkName: "Configuration" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'network_behavior_policies' }),
    goToItem: params => $router
      .push({ name: 'network_behavior_policy', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneNetworkBehaviorPolicy', params }),
    goToNew: params => $router.push({ name: 'newNetworkBehaviorPolicy', params })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_fingerbank)
    store.registerModule('$_fingerbank', FingerbankStoreModule)
  if (!store.state.$_network_behavior_policies)
    store.registerModule('$_network_behavior_policies', NetworkBehaviorPolicyStoreModule)
  next()
}

export default [
  {
    path: 'fingerbank/network_behavior_policies',
    name: 'network_behavior_policies',
    component: TheSearch,
    beforeEnter
  },
  {
    path: 'network_behavior_policies/new',
    name: 'newNetworkBehaviorPolicy',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'network_behavior_policy/:id',
    name: 'network_behavior_policy',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_network_behavior_policies/getNetworkBehaviorPolicy', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'network_behavior_policy/:id/clone',
    name: 'cloneNetworkBehaviorPolicy',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_network_behavior_policies/getNetworkBehaviorPolicy', to.params.id).then(() => {
        next()
      })
    }
  }
]
