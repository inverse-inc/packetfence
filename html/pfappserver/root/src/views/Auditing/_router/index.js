import acl from '@/utils/acl'
import store from '@/store'
import LiveLogs from '../_store/liveLogs'
import AdminApiLogsRoutes from '../adminApiLogs/_router'
import DhcpOption82LogsRoutes from '../dhcpOption82Logs/_router'
import DnsLogsRoutes from '../dnsLogs/_router'
import RadiusLogsRoutes from '../radiusLogs/_router'

const AuditingView = () => import(/* webpackChunkName: "Auditing" */ '../')
const LiveLogCreate = () => import(/* webpackChunkName: "Auditing" */ '../_components/LiveLogCreate')
const LiveLogView = () => import(/* webpackChunkName: "Auditing" */ '../_components/LiveLogView')

const route = {
  path: '/auditing',
  name: 'auditing',
  redirect: '/auditing/radiuslogs/search',
  component: AuditingView,
  meta: {
    can: () => acl.$some('read', ['radius_log', 'dhcp_option_82', 'dns_log', 'admin_api_audit_log', 'system']), // has ACL for 1+ children
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  beforeEnter: (to, from, next) => {
    if (!store.state.$_live_logs) {
      store.registerModule('$_live_logs', LiveLogs)
    }
    next()
  },
  children: [
    ...AdminApiLogsRoutes,
    ...DhcpOption82LogsRoutes,
    ...DnsLogsRoutes,
    ...RadiusLogsRoutes,

    {
      path: 'live/',
      name: 'live_logs',
      component: LiveLogCreate,
      props: (route) => ({ query: route.query.query }),
      meta: {
        can: 'read system',
        isFailRoute: true
      }
    },
    {
      path: 'live/:id',
      name: 'live_log',
      component: LiveLogView,
      props: (route) => ({ id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!(to.params.id in store.state.$_live_logs)) {
          next('/auditing/live')
        }
        else {
          next()
        }
      },
      meta: {
        can: 'read system'
      }
    }
  ]
}

export default route
