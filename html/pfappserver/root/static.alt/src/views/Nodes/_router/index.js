import NodesView from '../'
import NodesSearch from '../_components/NodesSearch'
import NodesCreate from '../_components/NodesCreate'

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
    }
  ]
}

export default route
