import store from '@/store'
import StoreModule from './_store'

const TheSearch = () => import(/* webpackChunkName: "Configuration" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'sources' }),
    goToItem: params => $router
      .push({ name: 'source', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneAuthenticationSource', params: { ...params, sourceType: params.type } }),
    goToNew: params => $router.push({ name: 'newAuthenticationSource', params }),
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_sources)
    store.registerModule('$_sources', StoreModule)
  next()
}

export default [
  {
    path: 'sources',
    name: 'sources',
    component: TheSearch,
    beforeEnter
  },
  {
    path: 'sources/new/:sourceType',
    name: 'newAuthenticationSource',
    component: TheView,
    props: (route) => ({ isNew: true, sourceType: route.params.sourceType }),
    beforeEnter
  },
  {
    path: 'source/:id',
    name: 'source',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_sources/getAuthenticationSource', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'source/:id/clone/:sourceType',
    name: 'cloneAuthenticationSource',
    component: TheView,
    props: (route) => ({ id: route.params.id, sourceType: route.params.sourceType, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_sources/getAuthenticationSource', to.params.id).then(() => {
        next()
      })
    }
  }
]
