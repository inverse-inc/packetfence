import store from '@/store'
import FingerbankStoreModule from '@/views/Configuration/fingerbank/_store'

const TheStep = () => import(/* webpackChunkName: "Configurator" */ './_components/TheStep')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_fingerbank)
    store.registerModule('$_fingerbank', FingerbankStoreModule) // required by FingerbankView
  next()
}

export default [
  {
    path: 'fingerbank',
    name: 'configurator-fingerbank',
    component: TheStep,
    beforeEnter
  }
]
