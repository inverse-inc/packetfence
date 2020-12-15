import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Editor" */ '../_components/FilterEnginesList')
const TheView = () => import(/* webpackChunkName: "Editor" */ './_components/TheView')

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
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter
  },
  {
    path: 'filter_engines/:collection',
    name: 'filterEnginesCollection',
    component: TheList,
    props: (route) => ({ collection: route.params.collection, query: route.query.query }),
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
    path: 'filter_engines/:collection/:id',
    name: 'filter_engine',
    component: TheView,
    props: (route) => ({ collection: route.params.collection, id: route.params.id }),
    beforeEnter
  },
  {
    path: 'filter_engines/:collection/:id/clone',
    name: 'cloneFilterEngine',
    component: TheView,
    props: (route) => ({ collection: route.params.collection, id: route.params.id, isClone: true }),
    beforeEnter
  }
]
