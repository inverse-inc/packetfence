import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/AuthenticationSourcesList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'sources' }),
    goToItem: params => $router
      .push({ name: 'source', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneAuthenticationSource', params }),
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
    component: TheList,
    props: (route) => ({ query: route.query.query }),
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
    path: 'source/:id/clone',
    name: 'cloneAuthenticationSource',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_sources/getAuthenticationSource', to.params.id).then(() => {
        next()
      })
    }
  }
]
