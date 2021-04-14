import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/RemoteConnectionProfilesList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_remote_connection_profiles) {
    store.registerModule('$_remote_connection_profiles', StoreModule)
  }
  next()
}

export default [
  {
    path: 'remote_connection_profiles',
    name: 'remote_connection_profiles',
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter
  },
  {
    path: 'remote_connection_profiles/new',
    name: 'newRemoteConnectionProfile',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'remote_connection_profile/:id',
    name: 'remote_connection_profile',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_remote_connection_profiles/getRemoteConnectionProfile', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'remote_connection_profile/:id/clone',
    name: 'cloneRemoteConnectionProfile',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_remote_connection_profiles/getRemoteConnectionProfile', to.params.id).then(() => {
        next()
      })
    }
  }
]
