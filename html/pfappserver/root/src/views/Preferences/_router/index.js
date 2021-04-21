const PreferencesView = () => import(/* webpackChunkName: "Preferences" */ '../')
const TheView = () => import(/* webpackChunkName: "Preferences" */ '../_components/TheView')

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
      props: (route) => ({ query: route.query.query, tab: 'settings' })
    },
    {
      path: 'permissions',
      name: 'preferencesPermissions',
      component: TheView,
      props: (route) => ({ query: route.query.query, tab: 'permissions' })
    }
  ]
}

export default route
