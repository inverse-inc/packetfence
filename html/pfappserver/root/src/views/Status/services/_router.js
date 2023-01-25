import store from '@/store'
import acl from '@/utils/acl'

const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (acl.$can('read', 'system')) {
    store.dispatch('system/getHostname').then(() => {
      store.dispatch('cluster/getConfig').then(() => {
        store.dispatch('$_status/allCharts').finally(() => next())
      }).catch(() => next())
    })
  }
  else
    next()
}

export default [
  {
    path: 'services',
    name: 'statusServices',
    component: TheView,
    beforeEnter,
    meta: {
      can: 'read services',
      isFailRoute: true
    }
  }
]
