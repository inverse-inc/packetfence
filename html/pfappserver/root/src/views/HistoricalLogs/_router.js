import store from '@/store'
import { loadClusterConfig } from '@/utils/cluster'
import StoreModule from './_store/sessions'

const TheForm = () => import(/* webpackChunkName: "HistoricalLogs" */ './_components/TheForm')
const TheView = () => import(/* webpackChunkName: "HistoricalLogs" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_historical_logs) {
    store.registerModule('$_historical_logs', StoreModule)
  }
  loadClusterConfig()
  const isFromHistorical = from && from.path && from.path.startsWith('/historical-logs')
  if (to && to.name === 'historical_logs' && !isFromHistorical) {
    const state = store.state.$_historical_logs
    if (state && state._lastSessionId && state._lastSessionId in state) {
      next({ name: 'historical_log', params: { id: state._lastSessionId } })
      return
    }
  }
  next()
}

export default [
  {
    path: '/historical-logs',
    name: 'historical_logs',
    component: TheForm,
    meta: {
      can: 'read system',
      isFailRoute: true
    },
    beforeEnter
  },
  {
    path: '/historical-logs/:id',
    name: 'historical_log',
    component: TheView,
    props: route => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      if (!(to.params.id in store.state.$_historical_logs)) {
        next('/historical-logs')
      } else {
        store.commit('$_historical_logs/SET_LAST_SESSION', to.params.id)
        next()
      }
    },
    meta: {
      can: 'read system'
    }
  }
]
