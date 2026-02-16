import store from '@/store'
import BasesStoreModule from './_store'

const TheView = () => import(/* webpackChunkName: "ConfigurationSystem" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_kafka) {
    store.registerModule('$_kafka', BasesStoreModule)
  }
  next()
}

export default [
  {
    path: 'kafka',
    name: 'kafka',
    component: TheView,
    beforeEnter
  }
]
