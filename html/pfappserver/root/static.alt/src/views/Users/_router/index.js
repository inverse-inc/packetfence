import store from '@/store'
import UsersView from '../'
import UsersStore from '../_store'
import UsersSearch from '../_components/UsersSearch'
import UsersCreate from '../_components/UsersCreate'
import UserView from '../_components/UserView'
import SearchableStore from '@/store/base/searchable'

const route = {
  path: '/users',
  name: 'users',
  redirect: '/users/search',
  component: UsersView,
  meta: { transitionDelay: 300 * 2 }, // See _transitions.scss => $slide-bottom-duration
  beforeEnter: (to, from, next) => {
    if (!store.state.$_users) {
      // Register store module only once
      store.registerModule('$_users', UsersStore)
      if (!store.state.$_users_searchable) {
        // Register store module only once
        const searchableStore = new SearchableStore(
          UsersSearch.pfMixinSearchableOptions.searchApiEndpoint,
          UsersSearch.pfMixinSearchableOptions.defaultSortKeys
        )
        store.registerModule('$_users_searchable', searchableStore.module())
      }
    }
    next()
  },
  children: [
    {
      path: 'search',
      component: UsersSearch,
      props: (route) => ({ query: route.query.query })
    },
    {
      path: 'create',
      component: UsersCreate
    },
    {
      path: '/user/:pid',
      name: 'user',
      component: UserView,
      props: true,
      beforeEnter: (to, from, next) => {
        store.dispatch('$_users/getUser', to.params.pid).then(user => {
          next()
        })
      }
    }
  ]
}

export default route
