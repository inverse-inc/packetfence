import store from '@/store'
import StoreModule from '../_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../../_components/TheTabsPkis')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

const beforeEnter = (to, from, next = () => { }) => {
  if (!store.state.$_pkis)
    store.registerModule('$_pkis', StoreModule)
  store.dispatch('cluster/getServiceCluster', 'pfpki')
    .then(next)
}

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'pkiScepServers' }),
    goToItem: params => $router
      .push({ name: 'pkiScepServer', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'clonePkiScepServer', params }),
    goToNew: params => $router.push({ name: 'newPkiScepServer', params })
  }
}

export default [
  {
    path: 'pki/scepservers',
    name: 'pkiScepServers',
    component: TheTabs,
    props: () => ({ tab: 'pkiScepServers' }),
    beforeEnter
  },
  {
    path: 'pki/scepservers/new',
    name: 'newPkiScepServer',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'pki/scepserver/:id',
    name: 'pkiScepServer',
    component: TheView,
    props: (route) => ({ id: String(route.params.id).toString() }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getScepServer', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pki/scepserver/:id/clone',
    name: 'clonePkiScepServer',
    component: TheView,
    props: (route) => ({ id: String(route.params.id).toString(), isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getScepServer', to.params.id).then(() => {
        next()
      })
    }
  }
]