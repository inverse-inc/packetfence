import store from '@/store'
import { modes, libraries } from '../_components/Chart'

export default [
  {
    name: 'Authentication', // i18n defer
    groups: [
      {
        name: 'Authentication Sources', // i18n defer
        items: () => {
          const { state: { config: { sources = [] } = {} } = {} } = store
          return [].concat.apply([], sources.filter(source => source.monitor && source.host).map(source => {
            return source.host.split(',').map(host => {
              return {
                title: `${source.description} - ping ${host}`,
                metric: `fping.${host.replace(/\./g, '_')}_latency`,
                mode: modes.LOCAL,
                library: libraries.DYGRAPH,
                cols: 6
              }
            })
          }))
        }
      },
      {
        name: 'Successful & Unsuccessful RADIUS Authentications', // i18n defer
        items: [
          {
            title: 'Successful RADIUS authentications in the last day', // i18n defer
            metric: 'statsd_gauge_source.packetfence.authentication.success_last_day',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Failed RADIUS authentications in the last day', // i18n defer
            metric: 'statsd_gauge_source.packetfence.authentication.failed_last_day',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          }
        ]
      }
    ]
  }
]