import acl from '@/utils/acl'
import store from '@/store'
import FormStore from '@/store/base/form'
import UsersView from '../'
import UsersStore from '../_store'

const UsersSearch = () => import(/* webpackChunkName: "Users" */ '../_components/UsersSearch')
const UsersCreate = () => import(/* webpackChunkName: "Users" */ '../_components/UsersCreate')
const UsersPreview = () => import(/* webpackChunkName: "Users" */ '../_components/UsersPreview')
const UserView = () => import(/* webpackChunkName: "Users" */ '../_components/UserView')
const UsersImport = () => import(/* webpackChunkName: "Editor" */ '../_components/UsersImport')

const route = {
  path: '/users',
  name: 'users',
  redirect: '/users/search',
  component: UsersView,
  meta: {
    can: () => (acl.$can('read', 'users') || acl.$can('create', 'users')), // has ACL for 1+ children
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  props: { storeName: '$_users' },
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
        can: 'read users',
        isFailRoute: true
      }
    },
    {
      path: 'create',
      component: UsersCreate,
      props: { formStoreName: 'formUsersCreate' },
      beforeEnter: (to, from, next) => {
        if (!store.state.formUsersCreate) { // Register store module only once
          store.registerModule('formUsersCreate', FormStore)
        }
        next()
      },
      meta: {
        can: 'create users'
      }
    },
    {
      path: 'import',
      component: UsersImport,
      props: (route) => ({ formStoreName: 'formUserImport' }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formUserImport) { // Register store module only once
          store.registerModule('formUserImport', FormStore)
        }
        next()
      },
      meta: {
        can: 'create users'
      }
    },
    {
      path: 'preview',
      name: 'usersPreview',
      component: UsersPreview,
      props: { storeName: '$_users' },
      meta: {
        can: 'create users'
      }
    },
    {
      path: '/user/:pid',
      name: 'user',
      component: UserView,
      props: (route) => ({ formStoreName: 'formUserView', pid: route.params.pid }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formUserView) { // Register store module only once
          store.registerModule('formUserView', FormStore)
        }
        store.dispatch('$_users/getUser', to.params.pid).then(() => {
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
