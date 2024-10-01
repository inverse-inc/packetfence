import { modes, libraries } from '../_components/Chart'

export default [
  {
    name: 'Apache', // i18n defer
    groups: [
      {
        name: 'Bandwidth', // i18n defer
        items: [
          {
            title: 'API Bandwidth', // i18n defer
            metric: 'web_log_api-frontend.bandwidth',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'AAA Bandwidth', // i18n defer
            metric: 'web_log_httpd_aaa.bandwidth',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Captive Portal Bandwidth', // i18n defer
            metric: 'web_log_httpd_portal.bandwidth',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Web Services Bandwidth', // i18n defer
            metric: 'web_log_httpd_webservices.bandwidth',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          }
        ]
      },
      {
        name: 'Requests', // i18n defer
        items: [
          {
            title: 'API Requests', // i18n defer
            metric: 'web_log_api-frontend.requests_by_http_method',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'AAA Requests', // i18n defer
            metric: 'web_log_httpd_aaa.requests_by_http_method',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Captive Portal Requests', // i18n defer
            metric: 'web_log_httpd_portal.requests_by_http_method',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Web Services Requests', // i18n defer
            metric: 'web_log_httpd_webservices.requests_by_http_method',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          }
        ]
      },
      {
        name: 'API Responses', // i18n defer
        items: ['responses_by_status_code_class', 'status_code_class_1xx_responses', 'status_code_class_2xx_responses', 'status_code_class_3xx_responses', 'status_code_class_4xx_responses', 'status_code_class_5xx_responses'].map(type => {
          return {
            title: type,
            metric: 'web_log_api-frontend.' + type,
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: (type.match(/^responses_by_status_code_class/)) ? 12 : 4
          }
        })
      },
      {
        name: 'AAA Responses', // i18n defer
        items: ['responses_by_status_code_class', 'status_code_class_1xx_responses', 'status_code_class_2xx_responses', 'status_code_class_3xx_responses', 'status_code_class_4xx_responses', 'status_code_class_5xx_responses'].map(type => {
          return {
            title: type,
            metric: 'web_log_httpd_aaa.' + type,
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: (type.match(/^responses_by_status_code_class/)) ? 12 : 4
          }
        })
      },
      {
        name: 'Captive Portal Responses', // i18n defer
        items: ['responses_by_status_code_class', 'status_code_class_1xx_responses', 'status_code_class_2xx_responses', 'status_code_class_3xx_responses', 'status_code_class_4xx_responses', 'status_code_class_5xx_responses'].map(type => {
          return {
            title: type,
            metric: 'web_log_httpd_portal.' + type,
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: (type.match(/^responses_by_status_code_class/)) ? 12 : 4
          }
        })
      },
      {
        name: 'Web Services Responses', // i18n defer
        items: ['responses_by_status_code_class', 'status_code_class_1xx_responses', 'status_code_class_2xx_responses', 'status_code_class_3xx_responses', 'status_code_class_4xx_responses', 'status_code_class_5xx_responses'].map(type => {
          return {
            title: type,
            metric: 'web_log_httpd_webservices.' + type,
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: (type.match(/^responses_by_status_code_class/)) ? 12 : 4
          }
        })
      },
    ]
  }
]