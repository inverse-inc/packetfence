import store from '@/store'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import NodesStoreModule from '../_store'
import UsersStoreModule from '../../Users/_store'
import NodesView from '../'
const NodesSearch = () => import(/* webpackChunkName: "Nodes" */ '../_components/NodesSearch')
const TheCsvImport = () => import(/* webpackChunkName: "Editor" */ '../_components/TheCsvImport')
const TheViewCreate = () => import(/* webpackChunkName: "Nodes" */ '../_components/TheViewCreate')
const TheViewUpdate = () => import(/* webpackChunkName: "Nodes" */ '../_components/TheViewUpdate')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_nodes)
    store.registerModule('$_nodes', NodesStoreModule)
  if (!store.state.$_users)
    store.registerModule('$_users', UsersStoreModule)
  next()
}

const route = {
  path: '/nodes',
  name: 'nodes',
  redirect: '/nodes/search',
  component: NodesView,
  meta: {
    can: () => (acl.$can('read', 'nodes') || acl.$can('create', 'nodes')), // has ACL for 1+ children
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  props: { storeName: '$_nodes' },
  beforeEnter,
  children: [
    {
      path: 'search',
      name: 'nodeSearch',
      component: NodesSearch,
      props: (route) => ({ query: route.query.query }),
      meta: {
        can: 'read nodes',
        isFailRoute: true
      }
    },
    {
      path: 'create',
      name: 'nodeCreate',
      component: TheViewCreate,
      meta: {
        can: 'create nodes'
      }
    },
    {
      path: 'import',
      name: 'nodeImport',
      component: TheCsvImport,
      meta: {
        can: 'create nodes'
      }
    },
    {
      path: '/node/:mac',
      name: 'node',
      component: TheViewUpdate,
      props: (route) => ({ id: route.params.mac }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_nodes/exists', to.params.mac).then(() => {
          next()
        }).catch(() => { // `mac` does not exist
          store.dispatch('notification/danger', { message: i18n.t('Node <code>{mac}</code> does not exist or is not available for this tenant.', to.params) })
          next({ name: 'nodeSearch' })
        })
      },
      meta: {
        can: 'read nodes'
      }
    }
  ]
}

export default route
