import store from '@/store'
import StoreModule from './_store'

const TheSearch = () => import(/* webpackChunkName: "Configuration" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'mfas' }),
    goToItem: params => $router
      .push({ name: 'mfa', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneMfa', params: { ...params, mfaType: params.type } }),
    goToNew: params => $router.push({ name: 'newMfa', params })
  }
}

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
    component: TheSearch,
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
    path: 'mfa/:id/clone/:mfaType',
    name: 'cloneMfa',
    component: TheView,
    props: (route) => ({ id: route.params.id, mfaType: route.params.mfaType, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_mfas/getMfa', to.params.id).then(() => {
        next()
      })
    }
  }
]
