import store from '@/store'
import PkiProvidersStoreModule from './_store'
import PkisStoreModule from '../pki/_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/PkiProvidersList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_pki_providers)
    store.registerModule('$_pki_providers', PkiProvidersStoreModule)
  if (!store.state.$_pkis)
    store.registerModule('$_pkis', PkisStoreModule)
  next()
}

export default [
  {
    path: 'pki_providers',
    name: 'pki_providers',
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter
  },
  {
    path: 'pki_providers/new/:providerType',
    name: 'newPkiProvider',
    component: TheView,
    props: (route) => ({ isNew: true, providerType: route.params.providerType }),
    beforeEnter
  },
  {
    path: 'pki_provider/:id',
    name: 'pki_provider',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pki_providers/getPkiProvider', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pki_provider/:id/clone',
    name: 'clonePkiProvider',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pki_providers/getPkiProvider', to.params.id).then(() => {
        next()
      })
    }
  }
]
