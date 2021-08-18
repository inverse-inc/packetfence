import store from '@/store'
import StoreModule from '../_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../../_components/TheTabsPkis')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_pkis)
    store.registerModule('$_pkis', StoreModule)
  next()
}

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'pkiProfiles' }),
    goToItem: params => $router
      .push({ name: 'pkiProfile', params: { ...params, id: params.ID } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'clonePkiProfile', params }),
    goToNew: params => $router.push({ name: 'newPkiProfile', params })
  }
}

export default [
  {
    path: 'pki/profiles',
    name: 'pkiProfiles',
    component: TheTabs,
    props: () => ({ tab: 'pkiProfiles' }),
    beforeEnter
  },
  {
    path: 'pki/ca/:ca_id/profiles/new',
    name: 'newPkiProfile',
    component: TheView,
    props: (route) => ({ ca_id: String(route.params.ca_id).toString(), isNew: true }),
    beforeEnter
  },
  {
    path: 'pki/profile/:id',
    name: 'pkiProfile',
    component: TheView,
    props: (route) => ({ id: String(route.params.id).toString() }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getProfile', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pki/profile/:id/clone',
    name: 'clonePkiProfile',
    component: TheView,
    props: (route) => ({ id: String(route.params.id).toString(), isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getProfile', to.params.id).then(() => {
        next()
      })
    }
  }
]
