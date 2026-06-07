import acl from '@/utils/acl'
import AdminApiLogsRoutes from '../adminApiLogs/_router'
import DhcpOption82LogsRoutes from '../dhcpOption82Logs/_router'
import DnsLogsRoutes from '../dnsLogs/_router'
import RadiusLogsRoutes from '../radiusLogs/_router'
import PftestRoutes from '../pftest/_router'

const TheView = () => import(/* webpackChunkName: "Auditing" */ '../')

const route = {
  path: '/auditing',
  name: 'auditing',
  redirect: '/auditing/radiuslogs/search',
  component: TheView,
  meta: {
    // 'services' is included so SERVICES_READ-only admins can reach pftest.
    can: () => acl.$some('read', ['radius_log', 'dhcp_option_82', 'dns_log', 'admin_api_audit_log', 'services']),
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  children: [
    ...AdminApiLogsRoutes,
    ...DhcpOption82LogsRoutes,
    ...DnsLogsRoutes,
    ...RadiusLogsRoutes,
    ...PftestRoutes
  ]
}

export default route
