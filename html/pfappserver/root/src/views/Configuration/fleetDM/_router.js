import store from '@/store'
import BasesStoreModule from '../bases/_store'

const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_bases) {
    store.registerModule('$_bases', BasesStoreModule)
  }
  next()
}

const can = () => !store.getters['system/isSaas']

export default [
  {
    path: 'fleetdm',
    name: 'fleetdm',
    component: TheView,
    meta: {
      can
    },
    beforeEnter
  }
]
