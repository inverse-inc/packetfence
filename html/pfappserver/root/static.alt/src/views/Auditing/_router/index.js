import store from '@/store'
import RadiusLogsStore from '../_store/radiusLogs'
import DhcpOption82LogsStore from '../_store/dhcpOption82Logs'
import DnsLogsStore from '../_store/dnsLogs'
import RadiusLogsSearch from '../_components/RadiusLogsSearch'
import DhcpOption82LogsSearch from '../_components/DhcpOption82LogsSearch'
import DnsLogsSearch from '../_components/DnsLogsSearch'

const AuditingView = () => import(/* webpackChunkName: "Auditing" */ '../')
const RadiusLogView = () => import(/* webpackChunkName: "Auditing" */ '../_components/RadiusLogView')
const DhcpOption82LogView = () => import(/* webpackChunkName: "Auditing" */ '../_components/DhcpOption82LogView')
const DnsLogView = () => import(/* webpackChunkName: "Auditing" */ '../_components/DnsLogView')

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
        store.dispatch('$_radius_logs/getItem', to.params.id).then(radiuslog => {
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
        store.dispatch('$_dhcpoption82_logs/getItem', to.params.mac).then(radiuslog => {
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
        store.dispatch('$_dns_logs/getItem', to.params.id).then(dnslog => {
          next()
        })
      },
      meta: {
        can: 'read dns_log'
      }
    },
  ]
}

export default route
