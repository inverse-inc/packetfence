import store from '@/store'
import { modes, libraries } from '../_components/Chart'

const chartDimensions = chart => {
  const definition = store.getters[`$_status/uniqueCharts`].find(o => o.id === chart)
  if (definition) {
    const { dimensions } = definition
    return Object.values(dimensions).map(dimension => dimension.name)
  }
  return []
}

export default [
  {
    name: 'Queue', // i18n defer
    groups: [
      {
        name: 'Queue counts', // i18n defer
        items: chartDimensions('packetfence.redis.queue_stats_count').map(queue => {
          return {
            title: queue + ' queue count', // i18n defer
            metric: 'packetfence.redis.queue_stats_count',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            params: {
              filter_graph: queue
            },
            cols: 6
          }
        })
      },
      {
        name: 'Queue tasks outstanding counts', // i18n defer
        items: chartDimensions('packetfence.redis.queue_stats_outstanding').map(task => {
          return {
            title: task + ' outstanding', // i18n defer
            metric: 'packetfence.redis.queue_stats_outstanding',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            params: {
              filter_graph: task.replace(/:/g, '_')
            },
            cols: 6
          }
        })
      },
      {
        name: 'Queue tasks expired counts', // i18n defer
        items: chartDimensions('packetfence.redis.queue_stats_expired').map(task => {
          return {
            title: task + ' expired', // i18n defer
            metric: 'packetfence.redis.queue_stats_expired',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            params: {
              filter_graph: task.replace(/:/g, '_')
            },
            cols: 6
          }
        })
      }
    ]
  }
]