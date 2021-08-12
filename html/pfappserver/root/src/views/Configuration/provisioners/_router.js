import store from '@/store'
import StoreModule from './_store'

const TheSearch = () => import(/* webpackChunkName: "Configuration" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'provisionings' }),
    goToItem: params => $router
      .push({ name: 'provisioning', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneProvisioning', params: { ...params, provisioningType: params.type } }),
    goToNew: params => $router.push({ name: 'newProvisioning', params })
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_provisionings) {
    store.registerModule('$_provisionings', StoreModule)
  }
  next()
}

export default [
  {
    path: 'provisionings',
    name: 'provisionings',
    component: TheSearch,
    beforeEnter
  },
  {
    path: 'provisionings/new/:provisioningType',
    name: 'newProvisioning',
    component: TheView,
    props: (route) => ({ isNew: true, provisioningType: route.params.provisioningType }),
    beforeEnter
  },
  {
    path: 'provisioning/:id',
    name: 'provisioning',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_provisionings/getProvisioning', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'provisioning/:id/clone/:provisioningType',
    name: 'cloneProvisioning',
    component: TheView,
    props: (route) => ({ id: route.params.id, provisioningType: route.params.provisioningType, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_provisionings/getProvisioning', to.params.id).then(() => {
        next()
      })
    }
  },
]
