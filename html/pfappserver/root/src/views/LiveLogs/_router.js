import store from '@/store'
import StoreModule from './_store/sessions'

const TheForm = () => import(/* webpackChunkName: "LiveLogs" */ './_components/TheForm')
const TheView = () => import(/* webpackChunkName: "LiveLogs" */ './_components/TheView')

// Lazily ensure the cluster/* store has its server list populated so the
// LiveLogs UI can decide whether to fan out per-peer (cluster) or use the
// single-session legacy path (standalone). Safe to call repeatedly: the
// underlying cluster action is idempotent on the cached config.
const loadClusterConfig = () => {
  if (store.state.cluster && store.dispatch) {
    return store.dispatch('cluster/getConfig').catch(() => {})
  }
  return Promise.resolve()
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_live_logs) {
    store.registerModule('$_live_logs', StoreModule)
  }
  loadClusterConfig()
  const isFromLiveLogs = from && from.path && from.path.startsWith('/live-logs')
  if (to && to.name === 'live_logs' && !isFromLiveLogs) {
    const liveLogsState = store.state.$_live_logs
    if (liveLogsState && liveLogsState._lastSessionId) {
      const id = liveLogsState._lastSessionId
      // Resolve either a single-session id (legacy) or a group_id (cluster).
      if (id in liveLogsState || (liveLogsState._groups && id in liveLogsState._groups)) {
        next({ name: 'live_log', params: { id } })
        return
      }
    }
  }
  next()
}

export default [
  {
    path: '/live-logs',
    name: 'live_logs',
    component: TheForm,
    meta: {
      can: 'read system',
      isFailRoute: true
    },
    beforeEnter
  },
  {
    path: '/live-logs/:id',
    name: 'live_log',
    component: TheView,
    props: route => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      const liveLogsState = store.state.$_live_logs
      const id = to.params.id
      const known = liveLogsState && (
        id in liveLogsState ||
        (liveLogsState._groups && id in liveLogsState._groups)
      )
      if (!known) {
        next('/live-logs')
      } else {
        store.commit('$_live_logs/SET_LAST_SESSION', id)
        next()
      }
    },
    meta: {
      can: 'read system'
    }
  }
]
