import NodesView from '../'
import NodesSearch from '../_components/NodesSearch'
import NodesCreate from '../_components/NodesCreate'
import NodeView from '../_components/NodeView'

const route = {
  path: '/nodes',
  name: 'nodes',
  redirect: '/nodes/search',
  component: NodesView,
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
      props: true
    }
  ]
}

export default route
