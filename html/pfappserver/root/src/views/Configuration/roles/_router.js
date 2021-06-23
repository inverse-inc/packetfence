import store from '@/store'
import RolesStoreModule from './_store'
import TrafficShapingPoliciesStoreModule from '../networks/trafficShapingPolicies/_store'

const TheSearch = () => import(/* webpackChunkName: "Configuration" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'roles' }),
    goToItem: params => $router
      .push({ name: 'role', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneRole', params }),
    goToNew: () => $router.push({ name: 'newRole' })
  }
}

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
    component: TheSearch,
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

