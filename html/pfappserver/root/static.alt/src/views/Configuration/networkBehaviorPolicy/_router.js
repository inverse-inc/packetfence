import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/NetworkBehaviorPoliciesList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export default [
  {
    path: 'fingerbank/network_behavior_policies',
    name: 'network_behavior_policies',
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter: (to, from, next) => {
      if (!store.state.$_network_behavior_policies) {
        store.registerModule('$_network_behavior_policies', StoreModule)
      }
      next()
    }
  },
  {
    path: 'network_behavior_policies/new',
    name: 'newNetworkBehaviorPolicy',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter: (to, from, next) => {
      if (!store.state.$_network_behavior_policies) {
        store.registerModule('$_network_behavior_policies', StoreModule)
      }
      next()
    }
  },
  {
    path: 'network_behavior_policy/:id',
    name: 'network_behavior_policy',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      if (!store.state.$_network_behavior_policies) {
        store.registerModule('$_network_behavior_policies', StoreModule)
      }
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
      if (!store.state.$_network_behavior_policies) {
        store.registerModule('$_network_behavior_policies', StoreModule)
      }
      store.dispatch('$_network_behavior_policies/getNetworkBehaviorPolicy', to.params.id).then(() => {
        next()
      })
    }
  }
]
