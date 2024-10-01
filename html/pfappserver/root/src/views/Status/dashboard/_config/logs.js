import { modes, libraries } from '../_components/Chart'

export default [
  {
    name: 'Logs', // i18n defer
    groups: [
      {
        name: 'packetfence.log events',
        items: [
          {
            title: 'Number of events', // i18n defer
            metric: 'packetfence.logs.packetfence_log',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Number of errors', // i18n defer
            metric: 'packetfence.logs.packetfence_error_log',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          }
        ]
      },
      {
        name: 'pfconnector-server events',
        items: [
          {
            title: 'Number of events', // i18n defer
            metric: 'packetfence.logs.pfconnector_server_log',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      },
      {
        name: 'pfconnector-client events',
        items: [
          {
            title: 'Number of events', // i18n defer
            metric: 'packetfence.logs.pfconnector_client_log',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      },
      {
        name: 'httpd.apache',
        items: [
          {
            title: 'Number of events', // i18n defer
            metric: 'packetfence.logs.httpd_apache',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      },
      {
        name: 'pfdhcp.log',
        items: [
          {
            title: 'Number of events', // i18n defer
            metric: 'packetfence.logs.pfdhcp_log',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      },
      {
        name: 'load_balancer.log',
        items: [
          {
            title: 'Number of events', // i18n defer
            metric: 'packetfence.logs.load_balancer_log',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      },
      {
        name: 'radius.log',
        items: [
          {
            title: 'Number of events', // i18n defer
            metric: 'packetfence.logs.radius_log',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      },
      {
        name: 'mariadb.log',
        items: [
          {
            title: 'Number of events', // i18n defer
            metric: 'packetfence.logs.mariadb_log',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      },
      {
        name: 'pfcron.log',
        items: [
          {
            title: 'Number of events', // i18n defer
            metric: 'packetfence.logs.pfcron_log',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      },
      {
        name: 'fingerbank.log',
        items: [
          {
            title: 'Number of events', // i18n defer
            metric: 'packetfence.logs.fingerbank_log',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      },
    ]
  }
]
