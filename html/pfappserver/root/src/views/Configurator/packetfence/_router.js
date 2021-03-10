import store from '@/store'
import BasesStoreModule from '@/views/Configuration/bases/_store'
import UsersStoreModule from '@/views/Users/_store/'

const TheStep = () => import(/* webpackChunkName: "Configurator" */ './_components/TheStep')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_bases)
    store.registerModule('$_bases', BasesStoreModule) // required by GeneralView
  if (!store.state.$_users)
    store.registerModule('$_users', UsersStoreModule) // required by AdministratorView
  next()
}

export default [
  {
    path: 'packetfence',
    name: 'configurator-packetfence',
    component: TheStep,
    beforeEnter
  }
]
