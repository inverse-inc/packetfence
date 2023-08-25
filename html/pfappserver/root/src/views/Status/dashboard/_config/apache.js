import { modes, libraries } from '../_components/Chart'

export default [
  {
    name: 'Apache', // i18n defer
    groups: [
      {
        name: 'Bandwidth', // i18n defer
        items: [
          {
            title: 'AAA Bandwidth', // i18n defer
            metric: 'web_log_apache_aaa_log.bandwidth',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 4
          },
          {
            title: 'Captive Portal Bandwidth', // i18n defer
            metric: 'web_log_apache_portal_log.bandwidth',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 4
          },
          {
            title: 'Web Services Bandwidth', // i18n defer
            metric: 'web_log_apache_webservices_log.bandwidth',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 4
          }
        ]
      },
      {
        name: 'AAA Responses', // i18n defer
        items: ['1xx', '2xx', '3xx', '4xx', '5xx', 'other'].map(http_code => {
          return {
            title: http_code + ' responses', // i18n defer
            metric: 'web_log_apache_aaa_log.response_codes',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            params: {
              filter_graph: http_code
            },
            cols: 4
          }
        })
      },
      {
        name: 'AAA Response Time', // i18n defer
        items: [
          {
            title: 'Response time', // i18n defer
            metric: 'web_log_apache_aaa_log.response_time',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            params: {
              filter_graph: 'avg'
            },
            cols: 12
          }
        ]
      },
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
            cols: 4
          }
        })
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
      },
      {
        name: 'Web Services Responses', // i18n defer
        items: ['1xx', '2xx', '3xx', '4xx', '5xx', 'other'].map(http_code => {
          return {
            title: http_code + ' responses', // i18n defer
            metric: 'web_log_apache_webservices_log.response_codes',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            params: {
              filter_graph: http_code
            },
            cols: 4
          }
        })
      },
      {
        name: 'Web Services Response Time', // i18n defer
        items: [
          {
            title: 'Response time', // i18n defer
            metric: 'web_log_apache_webservices_log.response_time',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            params: {
              filter_graph: 'avg'
            },
            cols: 12
          }
        ]
      },
    ]
  }
]