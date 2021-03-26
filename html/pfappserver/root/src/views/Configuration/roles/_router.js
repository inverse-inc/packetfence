import store from '@/store'
import RolesStoreModule from './_store'
import TrafficShapingPoliciesStoreModule from '../networks/trafficShapingPolicies/_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ './_components/TheList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_roles)
    store.registerModule('$_roles', RolesStoreModule)
  if (!store.state.$_traffic_shaping_policies)
    store.registerModule('$_traffic_shaping_policies', TrafficShapingPoliciesStoreModule)
  next()
}

export default [
  {
    path: 'roles',
    name: 'roles',
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter
  },
  {
    path: 'roles/:parentId',
    name: 'rolesByParentId',
    component: TheList,
    props: (route) => ({ parentId: route.params.parentId, query: route.query.query }),
    beforeEnter
  },
  {
    path: 'roles/new',
    name: 'newRole',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'role/:id',
    name: 'role',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_roles/getRole', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'role/:id/clone',
    name: 'cloneRole',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_roles/getRole', to.params.id).then(() => {
        next()
      })
    }
  }
]

