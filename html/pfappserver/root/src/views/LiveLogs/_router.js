import store from '@/store'
import StoreModule from './_store/sessions'

const TheForm = () => import(/* webpackChunkName: "LiveLogs" */ './_components/TheForm')
const TheView = () => import(/* webpackChunkName: "LiveLogs" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_live_logs) {
    store.registerModule('$_live_logs', StoreModule)
  }
  const isFromLiveLogs = from && from.path && from.path.startsWith('/live-logs')
  if (to && to.name === 'live_logs' && !isFromLiveLogs) {
    const liveLogsState = store.state.$_live_logs
    if (liveLogsState && liveLogsState._lastSessionId && liveLogsState._lastSessionId in liveLogsState) {
      next({ name: 'live_log', params: { id: liveLogsState._lastSessionId } })
      return
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
      if (!(to.params.id in store.state.$_live_logs))
        next('/live-logs')
      else {
        store.commit('$_live_logs/SET_LAST_SESSION', to.params.id)
        next()
      }
    },
    meta: {
      can: 'read system'
    }
  }
]
