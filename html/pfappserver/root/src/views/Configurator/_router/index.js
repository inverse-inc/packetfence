import TheView from '../'
import NetworkRoutes from '../network/_router'
import PacketfenceRoutes from '../packetfence/_router'
import FingerbankRoutes from '../fingerbank/_router'
import StatusRoutes from '../status/_router'

const route = {
  path: '/configurator',
  name: 'configurator',
  redirect: '/configurator/network/interfaces',
  component: TheView,
  meta: {
    transitionDelay: 150 // force scroll to the top
  },
  beforeEnter: (to, from, next) => {
    // do not include X-PacketFence-Tenant-Id header when in configrator, fixes #5610
    if (localStorage.getItem('X-PacketFence-Tenant-Id')) {
      localStorage.removeItem('X-PacketFence-Tenant-Id')
    }
    // Force initial visit to start with the first step
    if (!['configurator-network', 'configurator-interfaces'].includes(to.name)) {
      next({ name: 'configurator-network'})
    } else {
      next()
    }
  },
  children: [
    ...NetworkRoutes,
    ...PacketfenceRoutes,
    ...FingerbankRoutes,
    ...StatusRoutes
  ]
}

export default route
