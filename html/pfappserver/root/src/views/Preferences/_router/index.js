import store from '@/store'
import UsersStoreModule from '@/views/Users/_store'

const PreferencesView = () => import(/* webpackChunkName: "Preferences" */ '../')
const TheView = () => import(/* webpackChunkName: "Preferences" */ '../_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_users) {
    store.registerModule('$_users', UsersStoreModule)
  }
  next()
}

const route = {
  path: '/preferences',
  name: 'preferences',
  redirect: '/preferences/settings',
  component: PreferencesView,
  meta: {
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  children: [
    {
      path: 'settings',
      name: 'preferencesSettings',
      component: TheView,
      beforeEnter,
      props: (route) => ({ query: route.query.query, tab: 'settings' })
    },
    {
      path: 'permissions',
      name: 'preferencesPermissions',
      component: TheView,
      beforeEnter,
      props: (route) => ({ query: route.query.query, tab: 'permissions' })
    }
  ]
}

export default route
