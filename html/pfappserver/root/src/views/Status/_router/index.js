import acl from '@/utils/acl'
import store from '@/store'
import StatusView from '../'
import StatusStore from '../_store'

import AssetsRoutes from '../assets/_router'
import ClusterRoutes from '../cluster/_router'
import DashboardRoutes from '../dashboard/_router'
import QueueRoutes from '../queue/_router'
import NetworkCommunicationRoutes from '../network_communication/_router'
import NetworkThreatsRoutes from '../network_threats/_router'
import ServicesRoutes from '../services/_router'

const route = {
  path: '/status',
  name: 'status',
  redirect: '/status/dashboard',
  component: StatusView,
  meta: {
    can: () => acl.$some('read', ['system', 'services']), // has ACL for 1+ children
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
    ...AssetsRoutes,
    ...ClusterRoutes,
    ...DashboardRoutes,
    ...QueueRoutes,
    ...NetworkCommunicationRoutes,
    ...NetworkThreatsRoutes,
    ...ServicesRoutes,
  ]
}

export default route
