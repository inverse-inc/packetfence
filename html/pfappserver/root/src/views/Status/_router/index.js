import acl from '@/utils/acl'
import store from '@/store'
import StatusView from '../'
import StatusStore from '../_store'

import AssetsRoutes from '../assets/_router'
import DashboardRoutes from '../dashboard/_router'
import QueueRoutes from '../queue/_router'
import NetworkCommunicationRoutes from '../network_communication/_router'
import NetworkThreatsRoutes from '../network_threats/_router'
import ServicesRoutes from '../services/_router'

const beforeEnter = (to, from, next) => {
  if (!store.state.$_status) {
    // Register store module only once
    store.registerModule('$_status', StatusStore)
  }
  next()
}

const children = [
  ...DashboardRoutes,
  ...AssetsRoutes,
  ...QueueRoutes,
  ...NetworkCommunicationRoutes,
  ...NetworkThreatsRoutes,
  ...ServicesRoutes,
]

const path = '/status'

const redirect = () => {
  // find first child route that `can`
  for (let c = 0; c < children.length; c++) {
    const { [c]: { meta: { can } = {}, path: cPath } = {} } = children
    const redirect = `${path}/${cPath}`
    if (can) {
      if (can.constructor === Function && can()) {
        return redirect
      }
      if (can.constructor === String) {
        const { 0: verb, 1: action } = can.split(' ')
        if (acl.$can(verb, action)) {
          return redirect
        }
      }
    }
  }
}

const route = {
  path,
  name: 'status',
  redirect,
  component: StatusView,
  meta: {
    can: () => acl.$some('read', ['system', 'services']), // has ACL for 1+ children
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  beforeEnter,
  children
}

export default route
