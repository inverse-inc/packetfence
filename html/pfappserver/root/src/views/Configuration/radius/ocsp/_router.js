import store from '@/store'
import RadiusOcspStoreModule from './_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../../_components/RadiusTabs')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'radiusOcsps' }),
    goToItem: params => $router
      .push({ name: 'radiusOcsp', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneRadiusOcsp', params }),
    goToNew: params => $router.push({ name: 'newRadiusOcsp', params })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_radius_ocsp)
    store.registerModule('$_radius_ocsp', RadiusOcspStoreModule)
  next()
}

export default [
  {
    path: 'radius/ocsp',
    name: 'radiusOcsps',
    component: TheTabs,
    props: () => ({ tab: 'radiusOcsps' }),
    beforeEnter
  },
  {
    path: 'radius/ocsp_new',
    name: 'newRadiusOcsp',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'radius/ocsp/:id',
    name: 'radiusOcsp',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_radius_ocsp/getRadiusOcsp', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'radius/ocsp/:id/clone',
    name: 'cloneRadiusOcsp',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_radius_ocsp/getRadiusOcsp', to.params.id).then(() => {
        next()
      })
    }
  }
]
