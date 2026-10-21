import store from '@/store'
import StoreModule from '../_store'

const TheTabs = () => import(/* webpackChunkName: "ConfigurationIntegration" */ '../../_components/TheTabsPkis')
const TheView = () => import(/* webpackChunkName: "ConfigurationIntegration" */ './_components/TheView')

const beforeEnter = (to, from, next = () => { }) => {
  if (!store.state.$_pkis)
    store.registerModule('$_pkis', StoreModule)
  store.dispatch('cluster/getServiceCluster', 'pfpki')
    .then(next)
}

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'pkiHsms' }),
    goToItem: params => $router
      .push({ name: 'pkiHsm', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'clonePkiHsm', params }),
    goToNew: params => $router.push({ name: 'newPkiHsm', params })
  }
}

export default [
  {
    path: 'pki/hsms',
    name: 'pkiHsms',
    component: TheTabs,
    props: () => ({ tab: 'pkiHsms' }),
    beforeEnter
  },
  {
    path: 'pki/hsms/new',
    name: 'newPkiHsm',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'pki/hsm/:id',
    name: 'pkiHsm',
    component: TheView,
    props: (route) => ({ id: String(route.params.id).toString() }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getHsm', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pki/hsm/:id/clone',
    name: 'clonePkiHsm',
    component: TheView,
    props: (route) => ({ id: String(route.params.id).toString(), isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getHsm', to.params.id).then(() => {
        next()
      })
    }
  }
]