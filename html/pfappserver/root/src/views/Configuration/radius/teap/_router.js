import store from '@/store'
import RadiusTeapStoreModule from './_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../../_components/TheTabsRadius')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'radiusTeaps' }),
    goToItem: params => $router
      .push({ name: 'radiusTeap', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneRadiusTeap', params }),
    goToNew: params => $router.push({ name: 'newRadiusTeap', params })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_radius_teap)
    store.registerModule('$_radius_teap', RadiusTeapStoreModule)
  next()
}

export default [
  {
    path: 'radius/teap',
    name: 'radiusTeaps',
    component: TheTabs,
    props: () => ({ tab: 'radiusTeaps' }),
    beforeEnter
  },
  {
    path: 'radius/teap_new',
    name: 'newRadiusTeap',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'radius/teap/:id',
    name: 'radiusTeap',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_radius_teap/getRadiusTeap', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'radius/teap/:id/clone',
    name: 'cloneRadiusTeap',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_radius_teap/getRadiusTeap', to.params.id).then(() => {
        next()
      })
    }
  }
]
