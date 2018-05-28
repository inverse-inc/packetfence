import store from '@/store'
import NodesView from '../'
import NodesSearch from '../_components/NodesSearch'
const NodesCreate = () => import(/* webpackChunkName: "Nodes" */ '../_components/NodesCreate')
const NodeView = () => import(/* webpackChunkName: "Nodes" */ '../_components/NodeView')

const route = {
  path: '/nodes',
  name: 'nodes',
  redirect: '/nodes/search',
  component: NodesView,
  meta: { transitionDelay: 300 * 2 }, // See _transitions.scss => $slide-bottom-duration
  children: [
    {
      path: 'search',
      component: NodesSearch
    },
    {
      path: 'create',
      component: NodesCreate
    },
    {
      path: '/node/:mac',
      name: 'node',
      component: NodeView,
      props: true,
      beforeEnter: (to, from, next) => {
        store.dispatch('$_nodes/getNode', to.params.mac).then(node => {
          next()
        })
      }
    }
  ]
}

export default route
