import store from '@/store'
import StoreModule from '../_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../../_components/PkisTabs')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

const beforeEnter = (to, from, next = () => { }) => {
  if (!store.state.$_pkis)
    store.registerModule('$_pkis', StoreModule)
  next()
}

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'pkiCas' }),
    goToItem: params => $router
      .push({ name: 'pkiCa', params: { ...params, id: params.ID } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'clonePkiCa', params }),
  }
}

export default [
  {
    path: 'pki/cas',
    name: 'pkiCas',
    component: TheTabs,
    props: (route) => ({ tab: 'pkiCas', query: route.query.query }),
    beforeEnter
  },
  {
    path: 'pki/cas/new',
    name: 'newPkiCa',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'pki/ca/:id',
    name: 'pkiCa',
    component: TheView,
    props: (route) => ({ id: String(route.params.id).toString() }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getCa', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pki/ca/:id/clone',
    name: 'clonePkiCa',
    component: TheView,
    props: (route) => ({ id: String(route.params.id).toString(), isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getCa', to.params.id).then(() => {
        next()
      })
    }
  }
]