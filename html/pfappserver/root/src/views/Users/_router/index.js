import store from '@/store'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import UsersStoreModule from '../_store'
import UsersView from '../'
const UsersSearch = () => import(/* webpackChunkName: "Users" */ '../_components/UsersSearch')
const UsersPreview = () => import(/* webpackChunkName: "Users" */ '../_components/UsersPreview')
const TheCsvImport = () => import(/* webpackChunkName: "Editor" */ '../_components/TheCsvImport')
const TheViewCreate = () => import(/* webpackChunkName: "Users" */ '../_components/TheViewCreate')
const TheViewUpdate = () => import(/* webpackChunkName: "Users" */ '../_components/TheViewUpdate')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_users) {
    store.registerModule('$_users', UsersStoreModule)
  }
  next()
}

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
  beforeEnter,
  children: [
    {
      path: 'search',
      name: 'userSearch',
      component: UsersSearch,
      props: (route) => ({ query: route.query.query }),
      meta: {
        can: 'read users',
        isFailRoute: true
      }
    },
    {
      path: 'create',
      name: 'userCreate',
      component: TheViewCreate,
      meta: {
        can: 'create users'
      }
    },
    {
      path: 'import',
      name: 'userImport',
      component: TheCsvImport,
      meta: {
        can: 'create users'
      }
    },
    {
      path: 'preview',
      name: 'usersPreview',
      component: UsersPreview,
      meta: {
        can: 'create users'
      }
    },
    {
      path: '/user/:pid',
      name: 'user',
      component: TheViewUpdate,
      props: (route) => ({ pid: route.params.pid }),
      meta: {
        can: 'read users'
      },
      beforeEnter: (to, from, next) => {
        beforeEnter()
        store.dispatch('$_users/getUser', to.params.pid).then(() => {
          next()
        }).catch(() => { // `pid` does not exist
          store.dispatch('notification/danger', { message: i18n.t('User <code>{pid}</code> does not exist or is not available for this tenant.', to.params) })
          next({ name: 'userSearch' })
        })
      }
    }
  ]
}

export default route
