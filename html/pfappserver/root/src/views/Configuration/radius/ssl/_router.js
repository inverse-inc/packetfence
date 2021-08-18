import store from '@/store'
import RadiusSslStoreModule from './_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../../_components/TheTabsRadius')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'radiusSsls' }),
    goToItem: params => $router
      .push({ name: 'radiusSsl', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneRadiusSsl', params }),
    goToNew: params => $router.push({ name: 'newRadiusFast', params })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_radius_ssl)
    store.registerModule('$_radius_ssl', RadiusSslStoreModule)
  next()
}

export default [
  {
    path: 'radius/ssl',
    name: 'radiusSsls',
    component: TheTabs,
    props: () => ({ tab: 'radiusSsls' }),
    beforeEnter
  },
  {
    path: 'radius/ssl_new',
    name: 'newRadiusSsl',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'radius/ssl/:id',
    name: 'radiusSsl',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_radius_ssl/getRadiusSsl', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'radius/ssl/:id/clone',
    name: 'cloneRadiusSsl',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_radius_ssl/getRadiusSsl', to.params.id).then(() => {
        next()
      })
    }
  }
]
