import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import store from '@/store'
import FormStore from '@/store/base/form'
import NodesView from '../'
import NodesStore from '../_store'
import UsersStore from '../../Users/_store'
import NodesSearch from '../_components/NodesSearch'

const NodesCreate = () => import(/* webpackChunkName: "Nodes" */ '../_components/NodesCreate')
const NodeView = () => import(/* webpackChunkName: "Nodes" */ '../_components/NodeView')
const NodesImport = () => import(/* webpackChunkName: "Editor" */ '../_components/NodesImport')

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
  beforeEnter: (to, from, next) => {
    if (!store.state.$_nodes) {
      // Register store module only once
      store.registerModule('$_nodes', NodesStore)
    }
    if (!store.state.$_users) {
      // Register store module only once
      store.registerModule('$_users', UsersStore)
    }
    next()
  },
  children: [
    {
      path: 'search',
      name: 'nodeSearch',
      component: NodesSearch,
      props: (route) => ({ storeName: '$_nodes', query: route.query.query }),
      meta: {
        can: 'read nodes',
        isFailRoute: true
      }
    },
    {
      path: 'create',
      name: 'nodeCreate',
      component: NodesCreate,
      props: { formStoreName: 'formNodesCreate' },
      beforeEnter: (to, from, next) => {
        if (!store.state.formNodesCreate) { // Register store module only once
          store.registerModule('formNodesCreate', FormStore)
        }
        next()
      },
      meta: {
        can: 'create nodes'
      }
    },
    {
      path: 'import',
      name: 'nodeImport',
      component: NodesImport,
      meta: {
        can: 'create nodes'
      }
    },
    {
      path: '/node/:mac',
      name: 'node',
      component: NodeView,
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
