import store from '@/store'
import StoreModule from '../_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../../_components/PkisTabs')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_pkis)
    store.registerModule('$_pkis', StoreModule)
  next()
}

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'pkiRevokedCerts' }),
    goToItem: params => $router
      .push({ name: 'pkiRevokedCert', params: { ...params, id: params.ID } })
  }
}

export default [
  {
    path: 'pki/revokedcerts',
    name: 'pkiRevokedCerts',
    component: TheTabs,
    props: () => ({ tab: 'pkiRevokedCerts' }),
    beforeEnter
  },
  {
    path: 'pki/revokedcert/:id',
    name: 'pkiRevokedCert',
    component: TheView,
    props: (route) => ({ id: String(route.params.id).toString() }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getRevokedCert', to.params.id).then(() => {
        next()
      })
    }
  }
]
