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
  props: { storeName: '$_nodes' },
  meta: { transitionDelay: 300 * 2 }, // See _transitions.scss => $slide-bottom-duration
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
      name: 'search',
      component: NodesSearch,
      props: (route) => ({ storeName: '$_nodes', query: route.query.query }),
      meta: {
        can: 'read nodes',
        fail: { path: '/users', replace: true }
      }
    },
    {
      path: 'create',
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
      component: NodesImport,
      meta: {
        can: 'create nodes'
      }
    },
    {
      path: '/node/:mac',
      name: 'node',
      component: NodeView,
      props: (route) => ({ formStoreName: 'formNodeView', mac: route.params.mac }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formNodeView) { // Register store module only once
          store.registerModule('formNodeView', FormStore)
        }
        store.dispatch('$_nodes/getNode', to.params.mac).then(() => {
          next()
        })
      },
      meta: {
        can: 'read nodes'
      }
    }
  ]
}

export default route
