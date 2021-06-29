import store from '@/store'
import StoreModule from './_store'

const TheSearch = () => import(/* webpackChunkName: "Auditing" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Auditing" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_dhcpoption82_logs) {
    store.registerModule('$_dhcpoption82_logs', StoreModule)
  }
  next()
}

export default [
  {
    path: 'dhcpoption82s/search',
    name: 'dhcpoption82s',
    component: TheSearch,
    meta: {
      can: 'read dhcp_option_82',
      isFailRoute: true
    },
    beforeEnter
  },
  {
    path: 'dhcpoption82/:mac',
    name: 'dhcpoption82',
    component: TheView,
    props: (route) => ({ mac: route.params.mac }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_dhcpoption82_logs/getItem', to.params.mac).then(() => {
        next()
      })
    },
    meta: {
      can: 'read dhcp_option_82'
    }
  }
]