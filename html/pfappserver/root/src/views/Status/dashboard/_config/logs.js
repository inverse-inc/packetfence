import { modes, libraries } from '../_components/Chart'

export default [
  {
    name: 'Logs', // i18n defer
    groups: [
      {
        name: 'packetfence.log',
        items: [
          {
            title: 'Number of events', // i18n defer
            metric: 'packetfence.logs.packetfence_log',
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
        name: 'mariadb_error.log',
        items: [
          {
            title: 'Number of events', // i18n defer
            metric: 'packetfence.logs.mariadb_error_log',
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
      }
    ]
  }
]