import acl from '@/utils/acl'
import store from '@/store'
import StatusView from '../'
import StatusStore from '../_store'

import ClusterRoutes from '../cluster/_router'
import DashboardRoutes from '../dashboard/_router'
import QueueRoutes from '../queue/_router'
import NetworkRoutes from '../network/_router'
import ServicesRoutes from '../services/_router'

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
    next()
  },
  children: [
    ...ClusterRoutes,
    ...DashboardRoutes,
    ...QueueRoutes,
    ...NetworkRoutes,
    ...ServicesRoutes,
  ]
}

export default route
