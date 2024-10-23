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
            metric: 'statsd_source.packetfence.authentication.success_last_day_gauge',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Failed RADIUS authentications in the last day', // i18n defer
            metric: 'statsd_source.packetfence.authentication.failed_last_day_gauge',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          }
        ]
      },
      {
        name: 'NTLM Auth API', // i18n defer
        items: [
          {
            title: 'NTLM Auth API Bandwidth', // i18n defer
            metric: 'web_log_ntlm-auth-api.bandwidth',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'NTLM Auth API Requests', // i18n defer
            metric: 'web_log_ntlm-auth-api.requests_by_http_method',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            name: 'NTLM Auth API Responses', // i18n defer
            items: ['responses_by_status_code_class', 'status_code_class_1xx_responses', 'status_code_class_2xx_responses', 'status_code_class_3xx_responses', 'status_code_class_4xx_responses', 'status_code_class_5xx_responses'].map(type => {
              return {
                title: type,
                metric: 'web_log_ntlm-auth-api.' + type,
                mode: modes.COMBINED,
                library: libraries.DYGRAPH,
                cols: (type.match(/^responses_by_status_code_class/)) ? 12 : 4
              }
            })
          },

        ]
      }
    ]
  }
]