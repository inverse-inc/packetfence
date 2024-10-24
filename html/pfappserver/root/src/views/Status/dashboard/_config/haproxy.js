import store from '@/store'
import { modes, libraries } from '../_components/Chart'

const groups = [
  'haproxy-admin',
  'haproxy-db',
  'haproxy-portal',
]

const chartFactory = (match, factory) => {
  return store.getters[`$_status/uniqueCharts`].reduce((defs, chart) => {
    const matches = match(chart)
    if (matches) {
      const append = factory(chart, matches)
      defs = [ ...defs, ...Array.isArray(append) ? append : [append] ]
    }
    return defs
  }, [])
}

const pair = (array1, array2) => {
  return array1.reduce((paired, item, i) => {
    return (i in array2)
      ? [ ...paired, array1[i], array2[i] ]
      : [ ...paired, array1[i] ]
  }, [])
}

export default [
  {
    name: 'HAProxy', // i18n defer
    groups: groups.map(group => {
      return {
        name: group, // i18n defer
        items: [
          {
            title: 'Backend Current Sessions', // i18n defer
            metric: `haproxy_${group}.backend_current_sessions`,
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Backend Sessions', // i18n defer
            metric: `haproxy_${group}.backend_sessions`,
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Backend Response Time Average', // i18n defer
            metric: `haproxy_${group}.backend_response_time_average`,
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Backend Current Queue', // i18n defer
            metric: `haproxy_${group}.backend_current_queue`,
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          ...pair(
            chartFactory(
              ({ id }) => id.match(new RegExp(`^haproxy_${group}.backend_http_responses_proxy_([a-z0-9_.-]+)$`)),
              //eslint-disable-next-line
              (chart, [_, name]) => {
                return [
                  {
                    title: `HTTP Responses (${name})`, // i18n defer
                    metric: `haproxy_${group}.backend_http_responses_proxy_${name}`,
                    mode: modes.COMBINED,
                    library: libraries.DYGRAPH,
                    cols: 6
                  }
                ]
              }
            ),
            chartFactory(
              ({ id }) => id.match(new RegExp(`^haproxy_${group}.backend_network_io_proxy_([a-z0-9_.-]+)$`)),
              //eslint-disable-next-line
              (chart, [_, name]) => {
                return [
                  {
                    title: `Network I/O (${name})`, // i18n defer
                    metric: `haproxy_${group}.backend_network_io_proxy_${name}`,
                    mode: modes.COMBINED,
                    library: libraries.DYGRAPH,
                    cols: 6
                  }
                ]
              }
            )
          )
        ]
      }
    })
  }
]
