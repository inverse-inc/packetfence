import store from '@/store'
import RadiusLogsStore from '../_store/radiusLogs'
import DhcpOption82LogsStore from '../_store/dhcpOption82Logs'
import DnsLogsStore from '../_store/dnsLogs'
import AdminApiAuditLogs from '../_store/adminApiAuditLogs'
import LiveLogs from '../_store/liveLogs'

import RadiusLogsSearch from '../_components/RadiusLogsSearch'
import DhcpOption82LogsSearch from '../_components/DhcpOption82LogsSearch'
import DnsLogsSearch from '../_components/DnsLogsSearch'
import AdminApiAuditLogsSearch from '../_components/AdminApiAuditLogsSearch'

const AuditingView = () => import(/* webpackChunkName: "Auditing" */ '../')
const RadiusLogView = () => import(/* webpackChunkName: "Auditing" */ '../_components/RadiusLogView')
const DhcpOption82LogView = () => import(/* webpackChunkName: "Auditing" */ '../_components/DhcpOption82LogView')
const DnsLogView = () => import(/* webpackChunkName: "Auditing" */ '../_components/DnsLogView')
const AdminApiAuditLogView = () => import(/* webpackChunkName: "Auditing" */ '../_components/AdminApiAuditLogView')
const LiveLogCreate = () => import(/* webpackChunkName: "Auditing" */ '../_components/LiveLogCreate')
const LiveLogView = () => import(/* webpackChunkName: "Auditing" */ '../_components/LiveLogView')

const route = {
  path: '/auditing',
  name: 'auditing',
  redirect: '/auditing/radiuslogs/search',
  component: AuditingView,
  meta: {
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  beforeEnter: (to, from, next) => {
    if (!store.state.$_radius_logs) {
      store.registerModule('$_radius_logs', RadiusLogsStore)
    }
    if (!store.state.$_dhcpoption82_logs) {
      store.registerModule('$_dhcpoption82_logs', DhcpOption82LogsStore)
    }
    if (!store.state.$_dns_logs) {
      store.registerModule('$_dns_logs', DnsLogsStore)
    }
    if (!store.state.$_admin_api_audit_logs) {
      store.registerModule('$_admin_api_audit_logs', AdminApiAuditLogs)
    }
    if (!store.state.$_live_logs) {
      store.registerModule('$_live_logs', LiveLogs)
    }
    next()
  },
  children: [
    {
      path: 'radiuslogs/search',
      name: 'radiuslogs',
      component: RadiusLogsSearch,
      props: (route) => ({ storeName: '$_radius_logs', query: route.query.query }),
      meta: {
        can: 'read radius_log',
        fail: '/auditing/dhcpoption82s/search'
      }
    },
    {
      path: 'radiuslog/:id',
      name: 'radiuslog',
      component: RadiusLogView,
      props: (route) => ({ storeName: '$_radius_logs', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_radius_logs/getItem', to.params.id).then(() => {
          next()
        })
      },
      meta: {
        can: 'read radius_log'
      }
    },
    {
      path: 'dhcpoption82s/search',
      name: 'dhcpoption82s',
      component: DhcpOption82LogsSearch,
      props: (route) => ({ storeName: '$_dhcpoption82_logs', query: route.query.query }),
      meta: {
        can: 'read dhcp_option_82',
        fail: '/nodes'
      }
    },
    {
      path: 'dhcpoption82/:mac',
      name: 'dhcpoption82',
      component: DhcpOption82LogView,
      props: (route) => ({ storeName: '$_dhcpoption82_logs', mac: route.params.mac }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_dhcpoption82_logs/getItem', to.params.mac).then(() => {
          next()
        })
      },
      meta: {
        can: 'read dhcp_option_82'
      }
    },
    {
      path: 'dnslogs/search',
      name: 'dnslogs',
      component: DnsLogsSearch,
      props: (route) => ({ storeName: '$_dns_logs', query: route.query.query }),
      meta: {
        can: 'read dns_log',
        fail: '/auditing/dhcpoption82s/search'
      }
    },
    {
      path: 'dnslog/:id',
      name: 'dnslog',
      component: DnsLogView,
      props: (route) => ({ storeName: '$_dns_logs', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_dns_logs/getItem', to.params.id).then(() => {
          next()
        })
      },
      meta: {
        can: 'read dns_log'
      }
    },
    {
      path: 'admin_api_audit_logs/search',
      name: 'admin_api_audit_logs',
      component: AdminApiAuditLogsSearch,
      props: (route) => ({ storeName: '$_admin_api_audit_logs', query: route.query.query }),
      meta: {
        can: 'read admin_api_audit_log',
        fail: '/auditing/dnslogs/search'
      }
    },
    {
      path: 'admin_api_audit_log/:id',
      name: 'admin_api_audit_log',
      component: AdminApiAuditLogView,
      props: (route) => ({ storeName: '$_admin_api_audit_logs', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_admin_api_audit_logs/getItem', to.params.id).then(() => {
          next()
        })
      },
      meta: {
        can: 'read admin_api_audit_log'
      }
    },
    {
      path: 'live/',
      name: 'live_logs',
      component: LiveLogCreate,
      props: (route) => ({ storeName: '$_live_logs', query: route.query.query }),
      meta: {
        can: 'read system',
        fail: '/auditing'
      }
    },
    {
      path: 'live/:id',
      name: 'live_log',
      component: LiveLogView,
      props: (route) => ({ storeName: `$_live_log/${route.params.id}`, id: route.params.id }),
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
