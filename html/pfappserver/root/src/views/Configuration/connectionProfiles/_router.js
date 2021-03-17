import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/ConnectionProfilesList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_connection_profiles)
    store.registerModule('$_connection_profiles', StoreModule)
  next()
}

export default [
  {
    path: 'connection_profiles',
    name: 'connection_profiles',
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter
  },
  {
    path: 'connection_profiles/new',
    name: 'newConnectionProfile',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'connection_profile/:id',
    name: 'connection_profile',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_connection_profiles/getConnectionProfile', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'connection_profile/:id/clone',
    name: 'cloneConnectionProfile',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_connection_profiles/getConnectionProfile', to.params.id).then(() => {
        next()
      })
    }
  }
]
