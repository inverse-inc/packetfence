import store from '@/store'
import StoreModule from './_store'

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'dnslogs' }),
    goToItem: params => $router
      .push({ name: 'dnslog', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
  }
}

const TheSearch = () => import(/* webpackChunkName: "Auditing" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Auditing" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_dns_logs) {
    store.registerModule('$_dns_logs', StoreModule)
  }
  next()
}

export default [
  {
    path: 'dnslogs/search',
    name: 'dnslogs',
    component: TheSearch,
    meta: {
      can: 'read dns_log',
      isFailRoute: true
    },
    beforeEnter
  },
  {
    path: 'dnslog/:id',
    name: 'dnslog',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_dns_logs/getItem', to.params.id).then(() => {
        next()
      })
    },
    meta: {
      can: 'read dns_log'
    }
  }
]