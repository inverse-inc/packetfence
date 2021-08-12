import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ './_components/TheList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'portal_modules' }),
    goToItem: params => $router
      .push({ name: 'portal_module', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'clonePortalModule', params: { ...params, moduleType: params.type } }),
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_portalmodules)
    store.registerModule('$_portalmodules', StoreModule)
  next()
}

export default [
  {
    path: 'portal_modules',
    name: 'portal_modules',
    component: TheList,
    beforeEnter
  },
  {
    path: 'portal_modules/new/:moduleType',
    name: 'newPortalModule',
    component: TheView,
    props: (route) => ({ isNew: true, moduleType: route.params.moduleType }),
    beforeEnter
  },
  {
    path: 'portal_module/:id',
    name: 'portal_module',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_portalmodules/getPortalModule', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'portal_module/:id/clone/:moduleType',
    name: 'clonePortalModule',
    component: TheView,
    props: (route) => ({ id: route.params.id, moduleType: route.params.moduleType, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_portalmodules/getPortalModule', to.params.id).then(() => {
        next()
      })
    }
  }
]
