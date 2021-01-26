import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/PortalModulesList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

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
    props: (route) => ({ query: route.query.query }),
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
    path: 'portal_module/:id/clone',
    name: 'clonePortalModule',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_portalmodules/getPortalModule', to.params.id).then(() => {
        next()
      })
    }
  }
]
