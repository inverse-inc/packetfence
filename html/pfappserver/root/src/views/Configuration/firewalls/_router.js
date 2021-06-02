import store from '@/store'
import StoreModule from './_store'

const TheSearch = () => import(/* webpackChunkName: "Configuration" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'firewalls' }),
    goToItem: params => $router
      .push({ name: 'firewall', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneFirewall', params }),
    goToNew: params => $router.push({ name: 'newFirewall', params })
  }
}

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
    component: TheSearch,
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
