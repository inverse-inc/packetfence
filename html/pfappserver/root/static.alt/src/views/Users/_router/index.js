import store from '@/store'
import UsersView from '../'
import UsersStore from '../_store'
import UsersSearch from '../_components/UsersSearch'
import UsersCreate from '../_components/UsersCreate'
import UserView from '../_components/UserView'

const UsersImport = () => import(/* webpackChunkName: "Nodes" */ '../_components/UsersImport')

const route = {
  path: '/users',
  name: 'users',
  redirect: '/users/search',
  component: UsersView,
  props: { storeName: '$_users' },
  meta: { transitionDelay: 300 * 2 }, // See _transitions.scss => $slide-bottom-duration
  beforeEnter: (to, from, next) => {
    if (!store.state.$_users) {
      // Register store module only once
      store.registerModule('$_users', UsersStore)
    }
    next()
  },
  children: [
    {
      path: 'search',
      component: UsersSearch,
      props: (route) => ({ storeName: '$_users', query: route.query.query }),
      meta: {
        can: 'read users'
      }
    },
    {
      path: 'create',
      component: UsersCreate,
      props: { storeName: '$_users' },
      meta: {
        can: 'create users'
      }
    },
    {
      path: 'import',
      component: UsersImport,
      props: { storeName: '$_users' },
      meta: {
        can: 'create users'
      }
    },
    {
      path: '/user/:pid',
      name: 'user',
      component: UserView,
      props: (route) => ({ storeName: '$_users', pid: route.params.pid }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_users/getUser', to.params.pid).then(user => {
          next()
        })
      },
      meta: {
        can: 'read users'
      }
    }
  ]
}

export default route
