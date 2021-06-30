import acl from '@/utils/acl'
import AdminApiLogsRoutes from '../adminApiLogs/_router'
import DhcpOption82LogsRoutes from '../dhcpOption82Logs/_router'
import DnsLogsRoutes from '../dnsLogs/_router'
import RadiusLogsRoutes from '../radiusLogs/_router'
import LiveLogsRoutes from '../liveLogs/_router'

const TheView = () => import(/* webpackChunkName: "Auditing" */ '../')

const route = {
  path: '/auditing',
  name: 'auditing',
  redirect: '/auditing/radiuslogs/search',
  component: TheView,
  meta: {
    can: () => acl.$some('read', ['radius_log', 'dhcp_option_82', 'dns_log', 'admin_api_audit_log', 'system']), // has ACL for 1+ children
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  children: [
    ...AdminApiLogsRoutes,
    ...DhcpOption82LogsRoutes,
    ...DnsLogsRoutes,
    ...RadiusLogsRoutes,
    ...LiveLogsRoutes
  ]
}

export default route
