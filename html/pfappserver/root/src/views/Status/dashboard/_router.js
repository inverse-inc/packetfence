import store from '@/store'
import acl from '@/utils/acl'
import StoreModule from '../_store/'

const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_status)
    store.registerModule('$_status', StoreModule)
  next()
}

export default [
  {
    path: 'dashboard',
    name: 'statusDashboard',
    component: TheView,
    props: { storeName: '$_status' },
    beforeEnter: (to, from, next) => {
      beforeEnter()
      if (acl.$can('read', 'users_sources'))
        store.dispatch('config/getSources')
      if (acl.$can('read', 'system')) {
        store.dispatch('$_status/getCluster').then(() => {
          store.dispatch('$_status/allCharts').finally(() => next())
        }).catch(() => next())
      }
      else
        next()
    },
    meta: {
      can: 'master tenant',
      isFailRoute: true
    }
  }
]

