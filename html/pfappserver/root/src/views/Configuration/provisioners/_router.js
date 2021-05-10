import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/ProvisioningsList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'provisionings' }),
    goToItem: params => $router
      .push({ name: 'provisioning', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneProvisioning', params }),
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
    component: TheList,
    props: (route) => ({ query: route.query.query }),
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
    path: 'provisioning/:id/clone',
    name: 'cloneProvisioning',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_provisionings/getProvisioning', to.params.id).then(() => {
        next()
      })
    }
  },
]
