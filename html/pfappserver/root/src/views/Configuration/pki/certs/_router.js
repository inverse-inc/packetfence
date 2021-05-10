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
    goToCollection: () => $router.push({ name: 'pkiCerts' }),
    goToItem: params => $router
      .push({ name: 'pkiCert', params: { ...params, id: params.ID } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'clonePkiCert', params }),
  }
}

export default [
  {
    path: 'pki/certs',
    name: 'pkiCerts',
    component: TheTabs,
    props: (route) => ({ tab: 'pkiCerts', query: route.query.query }),
    beforeEnter
  },
  {
    path: 'pki/profile/:profile_id/certs/new',
    name: 'newPkiCert',
    component: TheView,
    props: (route) => ({ profile_id: String(route.params.profile_id).toString(), isNew: true }),
    beforeEnter
  },
  {
    path: 'pki/cert/:id',
    name: 'pkiCert',
    component: TheView,
    props: (route) => ({ id: String(route.params.id).toString() }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getCert', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pki/cert/:id/clone',
    name: 'clonePkiCert',
    component: TheView,
    props: (route) => ({ id: String(route.params.id).toString(), isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getCert', to.params.id).then(() => {
        next()
      })
    }
  }
]
