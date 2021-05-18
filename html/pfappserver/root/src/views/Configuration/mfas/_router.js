import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/MfasList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_mfas) {
    store.registerModule('$_mfas', StoreModule)
  }
  next()
}

export default [
  {
    path: 'mfas',
    name: 'mfas',
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter
  },
  {
    path: 'mfas/new/:mfaType',
    name: 'newMfa',
    component: TheView,
    props: (route) => ({ isNew: true, mfaType: route.params.mfaType }),
    beforeEnter
  },
  {
    path: 'mfa/:id',
    name: 'mfa',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_mfas/getMfa', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'mfa/:id/clone',
    name: 'cloneMfa',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_mfas/getMfa', to.params.id).then(() => {
        next()
      })
    }
  }
]
