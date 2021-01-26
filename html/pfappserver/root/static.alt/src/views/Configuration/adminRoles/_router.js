import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/AdminRolesList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_admin_roles)
    store.registerModule('$_admin_roles', StoreModule)
  next()
}

export default [
  {
    path: 'admin_roles',
    name: 'admin_roles',
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter
  },
  {
    path: 'admin_roles/new',
    name: 'newAdminRole',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'admin_role/:id',
    name: 'admin_role',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_admin_roles/getAdminRole', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'admin_role/:id/clone',
    name: 'cloneAdminRole',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_admin_roles/getAdminRole', to.params.id).then(() => {
        next()
      })
    }
  }
]

