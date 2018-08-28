import store from '@/store'
import UsersView from '../'
import UsersStore from '../_store'
import UsersSearch from '../_components/UsersSearch'
import UsersCreate from '../_components/UsersCreate'
import UserView from '../_components/UserView'

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
      props: (route) => ({ query: route.query.query, storeName: '$_users' })
    },
    {
      path: 'create',
      component: UsersCreate,
      props: { storeName: '$_users' }
    },
    {
      path: '/user/:pid',
      name: 'user',
      component: UserView,
      props: { storeName: '$_users' },
      beforeEnter: (to, from, next) => {
        store.dispatch('$_users/getUser', to.params.pid).then(user => {
          next()
        })
      }
    }
  ]
}

export default route
