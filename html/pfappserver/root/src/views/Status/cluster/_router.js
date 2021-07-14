import acl from '@/utils/acl'
import store from '@/store'

const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

const beforeEnter = (to, from, next = () => {}) => {
  if (acl.$can('read', 'system'))
    store.dispatch('$_status/getCluster').finally(() => next())
  else
    next()
}

export default [
  {
    path: 'cluster/services',
    name: 'statusCluster',
    component: TheView,
    beforeEnter,
    meta: {
      can: 'read services'
    }
  }
]
