import store from '@/store'
import RadiusEapStoreModule from './_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../../_components/RadiusTabs')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'radiusEaps' }),
    goToItem: params => $router
      .push({ name: 'radiusEap', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneRadiusEap', params }),
    goToNew: () => $router.push({ name: 'newRadiusEap' })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_radius_eap)
    store.registerModule('$_radius_eap', RadiusEapStoreModule)
  next()
}

export default [
  {
    path: 'radius/eap',
    name: 'radiusEaps',
    component: TheTabs,
    props: () => ({ tab: 'radiusEaps' }),
    beforeEnter
  },
  {
    path: 'radius/eap_new',
    name: 'newRadiusEap',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'radius/eap/:id',
    name: 'radiusEap',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_radius_eap/getRadiusEap', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'radius/eap/:id/clone',
    name: 'cloneRadiusEap',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_radius_eap/getRadiusEap', to.params.id).then(() => {
        next()
      })
    }
  }
]
