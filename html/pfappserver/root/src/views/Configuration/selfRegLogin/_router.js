import store from '@/store'
import BasesStoreModule from '../bases/_store'

const TheView = () => import(/* webpackChunkName: "ConfigurationSystem" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_bases) {
    store.registerModule('$_bases', BasesStoreModule)
  }
  next()
}

export default [
  {
    path: 'self_reg_login',
    name: 'self_reg_login',
    component: TheView,
    beforeEnter
  }
]
