import store from '@/store'
import BasesStoreModule from '@/views/Configuration/bases/_store'

const TheStep = () => import(/* webpackChunkName: "Configurator" */ './_components/TheStep')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_bases)
    store.registerModule('$_bases', BasesStoreModule) // required by StatusView
  next()
}

export default [
  {
    path: 'status',
    name: 'configurator-status',
    component: TheStep,
    beforeEnter
  }
]
