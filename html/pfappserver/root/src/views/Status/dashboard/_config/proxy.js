import { modes, libraries } from '../_components/Chart'



const extra = [

    'haproxy_haproxy-portal.backend_current_sessions',
    'haproxy_haproxy-portal.backend_sessions',
    'haproxy_haproxy-portal.backend_response_time_average',
    'haproxy_haproxy-portal.backend_queue_time_average',
    'haproxy_haproxy-portal.backend_current_queue',
    'haproxy_haproxy-portal.backend_http_responses_proxy_172.105.97.105-backend',
    'haproxy_haproxy-portal.backend_network_io_proxy_172.105.97.105-backend',
    'haproxy_haproxy-portal.backend_http_responses_proxy_pki',
    'haproxy_haproxy-portal.backend_network_io_proxy_pki',
    'haproxy_haproxy-portal.backend_http_responses_proxy_static',
    'haproxy_haproxy-portal.backend_network_io_proxy_static',
    'haproxy_haproxy-portal.backend_http_responses_proxy_proxy',
    'haproxy_haproxy-portal.backend_network_io_proxy_proxy',
    'haproxy_haproxy-portal.backend_http_responses_proxy_stats',
    'haproxy_haproxy-portal.backend_network_io_proxy_stats',


    'haproxy_haproxy-admin.backend_current_sessions',
    'haproxy_haproxy-admin.backend_sessions',
    'haproxy_haproxy-admin.backend_response_time_average',
    'haproxy_haproxy-admin.backend_queue_time_average',
    'haproxy_haproxy-admin.backend_current_queue',
    'haproxy_haproxy-admin.backend_http_responses_proxy_172.105.97.105-portal',
    'haproxy_haproxy-admin.backend_network_io_proxy_172.105.97.105-portal',
    'haproxy_haproxy-admin.backend_http_responses_proxy_containers-gateway.internal-api',
    'haproxy_haproxy-admin.backend_network_io_proxy_containers-gateway.internal-api',
    'haproxy_haproxy-admin.backend_http_responses_proxy_127.0.0.1-netdata',
    'haproxy_haproxy-admin.backend_network_io_proxy_127.0.0.1-netdata',
    'haproxy_haproxy-admin.backend_http_responses_proxy_api',
    'haproxy_haproxy-admin.backend_network_io_proxy_api',
    'haproxy_haproxy-admin.backend_http_responses_proxy_static',
    'haproxy_haproxy-admin.backend_network_io_proxy_static',
    'haproxy_haproxy-admin.backend_http_responses_proxy_stats',
    'haproxy_haproxy-admin.backend_network_io_proxy_stats',
].map(id => {
  return {
      title: id, // i18n defer
      metric: id,
      mode: modes.SINGLE,
      library: libraries.DYGRAPH,
      cols: 6
    }
})


export default [
  {
    name: 'Proxy', // i18n defer
    groups: [

      { name: 'Test', items: extra },
      {
        name: 'HAProxy', // i18n defer
        items: [
          {
            title: 'HAProxy CPU', // i18n defer
            metric: 'systemd_packetfence-haproxy-db.cpu',
            mode: modes.SINGLE,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'HAProxy Memory', // i18n defer
            metric: 'systemd_packetfence-haproxy-db.mem',
            mode: modes.SINGLE,
            library: libraries.DYGRAPH,
            cols: 6
          }
        ]
      },
      {
        name: 'ProxySQL', // i18n defer
        items: [
          {
            title: 'ProxySQL CPU', // i18n defer
            metric: 'systemd_packetfence-proxysql.cpu',
            mode: modes.SINGLE,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'ProxySQL Memory', // i18n defer
            metric: 'systemd_packetfence-proxysql.mem',
            mode: modes.SINGLE,
            library: libraries.DYGRAPH,
            cols: 6
          }
        ]
      }
    ]
  }
]