import store from '@/store'
import NodesView from '../'
import NodesStore from '../_store'
import NodesSearch from '../_components/NodesSearch'
const NodesCreate = () => import(/* webpackChunkName: "Nodes" */ '../_components/NodesCreate')
const NodeView = () => import(/* webpackChunkName: "Nodes" */ '../_components/NodeView')
const NodesUpload = () => import(/* webpackChunkName: "Nodes" */ '../_components/NodesUpload')

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
    next()
  },
  children: [
    {
      path: 'search',
      component: NodesSearch,
      props: (route) => ({ query: route.query.query, storeName: '$_nodes' })
    },
    {
      path: 'create',
      component: NodesCreate,
      props: { storeName: '$_nodes' }
    },
    {
      path: 'upload',
      component: NodesUpload,
      props: { storeName: '$_nodes' }
    },
    {
      path: '/node/:mac',
      name: 'node',
      component: NodeView,
      props: { storeName: '$_nodes' },
      beforeEnter: (to, from, next) => {
        store.dispatch('$_nodes/getNode', to.params.mac).then(node => {
          next()
        })
      }
    }
  ]
}

export default route
