import store from '@/store'
import acl from '@/utils/acl'

const TheView = () => import(/* webpackChunkName: "Status" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (acl.$can('read', 'system')) {
    store.dispatch('system/getHostname').finally(() => next())
  }
  else
    next()
}

export default [
  {
    path: 'services_saas',
    name: 'statusServicesSaas',
    component: TheView,
    beforeEnter,
    meta: {
      can: 'read services',
      isFailRoute: true
    }
  }
]
