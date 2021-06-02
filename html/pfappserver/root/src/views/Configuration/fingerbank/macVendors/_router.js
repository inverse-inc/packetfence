import { toRefs } from '@vue/composition-api'
import store from '@/store'
import { TheTabs } from '../_components/'
const TheView = () => import(/* webpackChunkName: "Fingerbank" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'fingerbankMacVendors' }),
    goToItem: params => $router
      .push({ name: 'fingerbankMacVendor', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneFingerbankMacVendor', params }),
    goToNew: params => $router.push({ name: 'newFingerbankMacVendor', params })
  }
}

export default [
  {
    path: 'fingerbank/mac_vendors',
    name: 'fingerbankMacVendors',
    component: TheTabs,
    props: () => ({ tab: 'mac_vendors', scope: 'all' })
  },
  {
    path: 'fingerbank/:scope/mac_vendors',
    name: 'fingerbankMacVendorsByScope',
    component: TheTabs,
    props: (route) => ({ tab: 'mac_vendors', scope: route.params.scope })
  },
  {
    path: 'fingerbank/:scope/mac_vendors/new',
    name: 'newFingerbankMacVendor',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, isNew: true })
  },
  {
    path: 'fingerbank/:scope/mac_vendor/:id',
    name: 'fingerbankMacVendor',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, id: route.params.id }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getMacVendor', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'fingerbank/:scope/mac_vendor/:id/clone',
    name: 'cloneFingerbankMacVendor',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getMacVendor', to.params.id).then(() => {
        next()
      })
    }
  }
]
