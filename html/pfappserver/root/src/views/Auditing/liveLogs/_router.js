import store from '@/store'
import StoreModule from './_store/sessions'

const TheForm = () => import(/* webpackChunkName: "Auditing" */ './_components/TheForm')
const TheView = () => import(/* webpackChunkName: "Auditing" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_live_logs) {
    store.registerModule('$_live_logs', StoreModule)
  }
  next()
}

export default [
  {
    path: 'live/',
    name: 'live_logs',
    component: TheForm,
    meta: {
      can: 'read system',
      isFailRoute: true
    },
    beforeEnter
  },
  {
    path: 'live/:id',
    name: 'live_log',
    component: TheView,
    props: route => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      if (!(to.params.id in store.state.$_live_logs))
        next('/auditing/live')
      else
        next()
    },
    meta: {
      can: 'read system'
    }
  }
]