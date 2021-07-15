import { modes, libraries } from '../_components/Chart'

export default [
  {
    name: 'Portal', // i18n defer
    groups: [
      {
        name: 'Captive Portal Responses', // i18n defer
        items: ['1xx', '2xx', '3xx', '4xx', '5xx', 'other'].map(http_code => {
          return {
            title: http_code + ' responses', // i18n defer
            metric: 'web_log_apache_portal_log.response_codes',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            params: {
              filter_graph: http_code
            },
            cols: 6
          }
        })
      },
      {
        name: 'Captive Portal Bandwidth', // i18n defer
        items: [
          {
            title: 'Bandwidth used', // i18n defer
            metric: 'web_log_apache_portal_log.bandwidth',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      },
      {
        name: 'Captive Portal Response Time', // i18n defer
        items: [
          {
            title: 'Response time', // i18n defer
            metric: 'web_log_apache_portal_log.response_time',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            params: {
              filter_graph: 'avg'
            },
            cols: 12
          }
        ]
      }
    ]
  }
]