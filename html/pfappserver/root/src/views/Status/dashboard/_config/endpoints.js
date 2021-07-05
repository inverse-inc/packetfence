import { modes, libraries } from '../_components/Chart'

export default [
  {
    name: 'Endpoints', // i18n defer
    groups: [
      {
        name: 'Registered & Unregistered Devices', // i18n defer
        items: [
          {
            title: 'Registration status of online devices', // i18n defer
            metric: 'packetfence.devices.registered_unregistered',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Devices currently registered', // i18n defer
            metric: 'statsd_gauge_source.packetfence.devices.registered',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            params: {
              filter_graph: 'gauge'
            },
            cols: 6
          }
        ]
      },
      {
        name: 'Registered Devices Per Role', // i18n defer
        items: [
          {
            title: 'Registered devices per role', // i18n defer
            metric: 'packetfence.devices.registered_per_role',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      },
      {
        name: 'Registered Devices Per Timeframe', // i18n defer
        items: ['hour', 'day', 'week', 'month', 'year'].map(scope => {
          return {
            title: `New registered devices during the past ${scope}`, // i18n defer
            metric: `statsd_gauge_source.packetfence.devices.registered_last_${scope}`,
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            params: {
              filter_graph: 'gauge'
            },
            cols: scope === 'year' ? 12 : 6
          }
        })
      },
      {
        name: 'Device Security Events', // i18n defer
        items: [
          {
            title: 'Currently open security events', // i18n defer
            metric: 'statsd_gauge_source.packetfence.security_events',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            params: {
              filter_graph: 'gauge'
            },
            cols: 12
          }
        ]
      }
    ]
  }
]