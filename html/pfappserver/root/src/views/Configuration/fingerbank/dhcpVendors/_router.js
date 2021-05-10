import { toRefs } from '@vue/composition-api'
import store from '@/store'
import { TheTabs } from '../_components/'
const TheView = () => import(/* webpackChunkName: "Fingerbank" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'fingerbankDhcpVendors' }),
    goToItem: (params, props) => {
      const { scope } = toRefs(props)
      $router
        .push({ name: 'fingerbankDhcpVendor', params: { ...params, scope: scope.value } })
        .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
    },
    goToClone: params => $router.push({ name: 'cloneFingerbankDhcpVendor', params: { ...params, scope: 'local' } })
  }
}

export default [
  {
    path: 'fingerbank/dhcp_vendors',
    name: 'fingerbankDhcpVendors',
    component: TheTabs,
    props: (route) => ({ tab: 'dhcp_vendors', query: route.query.query })
  },
  {
    path: 'fingerbank/:scope/dhcp_vendors/new',
    name: 'newFingerbankDhcpVendor',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, isNew: true })
  },
  {
    path: 'fingerbank/:scope/dhcp_vendor/:id',
    name: 'fingerbankDhcpVendor',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, id: route.params.id }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getDhcpVendor', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'fingerbank/:scope/dhcp_vendor/:id/clone',
    name: 'cloneFingerbankDhcpVendor',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getDhcpVendor', to.params.id).then(() => {
        next()
      })
    }
  }
]
