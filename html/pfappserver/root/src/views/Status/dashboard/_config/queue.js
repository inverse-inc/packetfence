import store from '@/store'
import { modes, libraries } from '../_components/Chart'

export default [
  {
    name: 'Queue', // i18n defer
    groups: [
      {
        name: 'Redis Queue', // i18n defer
        items: [
          {
            title: `redis_redis-queue.memory`,
            metric: `redis_redis-queue.memory`,
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: `redis_redis-queue.net`,
            metric: `redis_redis-queue.net`,
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: `redis_redis-queue.commands_calls`,
            metric: `redis_redis-queue.commands_calls`,
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: `redis_redis-queue.keys`,
            metric: `redis_redis-queue.keys`,
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          }
        ]
      },
      {
        name: 'Redis Cache', // i18n defer
        items: [
          {
            title: `redis_redis-cache.memory`,
            metric: `redis_redis-cache.memory`,
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: `redis_redis-cache.net`,
            metric: `redis_redis-cache.net`,
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: `redis_redis-cache.commands_calls`,
            metric: `redis_redis-cache.commands_calls`,
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: `redis_redis-cache.keys`,
            metric: `redis_redis-cache.keys`,
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          }
        ]
      }
    ]
  }
]