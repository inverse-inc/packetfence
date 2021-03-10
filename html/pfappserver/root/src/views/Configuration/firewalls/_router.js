import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/FirewallsList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_firewalls) {
    store.registerModule('$_firewalls', StoreModule)
  }
  next()
}

export default [
  {
    path: 'firewalls',
    name: 'firewalls',
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter
  },
  {
    path: 'firewalls/new/:firewallType',
    name: 'newFirewall',
    component: TheView,
    props: (route) => ({ isNew: true, firewallType: route.params.firewallType }),
    beforeEnter
  },
  {
    path: 'firewall/:id',
    name: 'firewall',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_firewalls/getFirewall', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'firewall/:id/clone',
    name: 'cloneFirewall',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_firewalls/getFirewall', to.params.id).then(() => {
        next()
      })
    }
  }
]
