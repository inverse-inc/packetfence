import acl from '@/utils/acl'
import store from '@/store'
import StatusView from '../'
import StatusStore from '../_store'

import DashboardRoutes from '../dashboard/_router'
import QueueRoutes from '../queue/_router'
import ServicesRoutes from '../services/_router'

import Network from '../_components/Network'
import ClusterServices from '../_components/ClusterServices'

const route = {
  path: '/status',
  name: 'status',
  redirect: '/status/dashboard',
  component: StatusView,
  meta: {
    can: () => acl.can('master tenant') || acl.$some('read', ['system', 'services']), // has ACL for 1+ children
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  beforeEnter: (to, from, next) => {
    if (!store.state.$_status) {
      // Register store module only once
      store.registerModule('$_status', StatusStore)
    }
    if (acl.$can('read', 'system'))
      store.dispatch('$_status/getCluster').finally(() => next())
    else
      next()
  },
  children: [
    ...DashboardRoutes,
    ...QueueRoutes,
    ...ServicesRoutes,
    {
      path: 'network',
      name: 'statusNetwork',
      component: Network,
      props: (route) => ({ query: route.query.query }),
      meta: {
        can: 'read nodes',
        isFailRoute: true
      }
    },
    {
      path: 'cluster/services',
      name: 'statusCluster',
      component: ClusterServices,
      props: { storeName: '$_status' },
      meta: {
        can: 'read services'
      }
    }
  ]
}

export default route
