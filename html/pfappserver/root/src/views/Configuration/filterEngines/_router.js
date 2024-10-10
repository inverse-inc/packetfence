import store from '@/store'
import StoreModule from './_store'

export const useRouter = $router => {
  return {
    goToCollection: params => $router.push({ name: 'filterEnginesCollection', params }),
    goToItem: params => $router
      .push({ name: 'filter_engine', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneFilterEngine', params }),
    goToNew: params => $router.push({ name: 'newFilterEngine', params })
  }
}

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ './_components/TheTabs')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_filter_engines) {
    store.registerModule('$_filter_engines', StoreModule)
  }
  next()
}

export default [
  {
    path: 'filter_engines',
    name: 'filter_engines',
    component: TheTabs,
    beforeEnter
  },
  {
    path: 'filter_engines/:collection',
    name: 'filterEnginesCollection',
    component: TheTabs,
    props: (route) => ({ collection: route.params.collection }),
    beforeEnter
  },
  {
    path: 'filter_engines/:collection/new',
    name: 'newFilterEngine',
    component: TheView,
    props: (route) => ({ collection: route.params.collection, isNew: true }),
    beforeEnter
  },
  {
    path: 'filter_engines/:collection/:type/new',
    name: 'newFilterEngineSubType',
    component: TheView,
    props: (route) => ({ collection: route.params.collection, type: route.params.type, isNew: true }),
    beforeEnter
  },
  {
    path: 'filter_engines/:collection/:id',
    name: 'filter_engine',
    component: TheView,
    props: (route) => ({ collection: route.params.collection, id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_filter_engines/getFilterEngine', { collection: to.params.collection, id: to.params.id })
        .finally(() => next())
    }
  },
  {
    path: 'filter_engines/:collection/:id/clone',
    name: 'cloneFilterEngine',
    component: TheView,
    props: (route) => ({ collection: route.params.collection, id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_filter_engines/getFilterEngine', { collection: to.params.collection, id: to.params.id })
        .finally(() => next())
    }
  }
]
