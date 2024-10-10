import store from '@/store'
import StoreModule from './_store'
import { analytics } from './config'

const TheSearch = () => import(/* webpackChunkName: "Configuration" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
 return {
    goToCollection: () => $router.push({ name: 'eventHandlers' }),
    goToItem: params => $router
      .push({ name: 'eventHandler', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneEventHandler', params: { ...params, eventHandlerType: params.type } }),
    goToNew: params => $router.push({ name: 'newEventHandler', params })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_event_handlers)
    store.registerModule('$_event_handlers', StoreModule)
  next()
}

export default [
  {
    path: 'pfdetect',
    name: 'eventHandlers',
    component: TheSearch,
    beforeEnter
  },
  {
    path: 'pfdetect/new/:eventHandlerType',
    name: 'newEventHandler',
    component: TheView,
    meta: {
      ...analytics
    },
    props: (route) => ({ isNew: true, eventHandlerType: route.params.eventHandlerType }),
    beforeEnter
  },
  {
    path: 'pfdetect/:id',
    name: 'eventHandler',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_event_handlers/getEventHandler', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pfdetect/:id/clone/:eventHandlerType',
    name: 'cloneEventHandler',
    component: TheView,
    meta: {
      ...analytics
    },
    props: (route) => ({ id: route.params.id, eventHandlerType: route.params.eventHandlerType, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_event_handlers/getEventHandler', to.params.id).then(() => {
        next()
      })
    }
  }
]
