import store from '@/store'
import StoreModule from './_store'

const TheSearch = () => import(/* webpackChunkName: "Configuration" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
 return {
    goToCollection: () => $router.push({ name: 'eventLoggers' }),
    goToItem: params => $router
      .push({ name: 'eventLogger', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneEventLogger', params: { ...params, eventLoggerType: params.type } }),
    goToNew: params => $router.push({ name: 'newEventLogger', params })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_event_loggers)
    store.registerModule('$_event_loggers', StoreModule)
  next()
}

export default [
  {
    path: 'event_loggers',
    name: 'eventLoggers',
    component: TheSearch,
    beforeEnter
  },
  {
    path: 'event_loggers/new/:eventLoggerType',
    name: 'newEventLogger',
    component: TheView,
    props: (route) => ({ isNew: true, eventLoggerType: route.params.eventLoggerType }),
    beforeEnter
  },
  {
    path: 'event_logger/:id',
    name: 'eventLogger',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_event_loggers/getEventLogger', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'event_logger/:id/clone/:eventLoggerType',
    name: 'cloneEventLogger',
    component: TheView,
    props: (route) => ({ id: route.params.id, eventLoggerType: route.params.eventLoggerType, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_event_loggers/getEventLogger', to.params.id).then(() => {
        next()
      })
    }
  }
]
