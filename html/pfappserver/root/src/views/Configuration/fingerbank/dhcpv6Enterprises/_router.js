import { toRefs } from '@vue/composition-api'
import store from '@/store'
import { TheTabs } from '../_components/'
const TheView = () => import(/* webpackChunkName: "Fingerbank" */ './_components/TheView')

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'fingerbankDhcpv6Enterprises' }),
    goToItem: params => $router
      .push({ name: 'fingerbankDhcpv6Enterprise', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneFingerbankDhcpv6Enterprise', params }),
    goToNew: params => $router.push({ name: 'newFingerbankDhcpv6Enterprise', params })
  }
}

export default [
  {
    path: 'fingerbank/dhcpv6_enterprises',
    name: 'fingerbankDhcpv6Enterprises',
    component: TheTabs,
    props: () => ({ tab: 'dhcpv6_enterprises', scope: 'all' })
  },
  {
    path: 'fingerbank/:scope/dhcpv6_enterprises',
    name: 'fingerbankDhcpv6EnterprisesByScope',
    component: TheTabs,
    props: (route) => ({ tab: 'dhcpv6_enterprises', scope: route.params.scope })
  },
  {
    path: 'fingerbank/:scope/dhcpv6_enterprises/new',
    name: 'newFingerbankDhcpv6Enterprise',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, isNew: true })
  },
  {
    path: 'fingerbank/:scope/dhcpv6_enterprise/:id',
    name: 'fingerbankDhcpv6Enterprise',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, id: route.params.id }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getDhcpv6Enterprise', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'fingerbank/:scope/dhcpv6_enterprise/:id/clone',
    name: 'cloneFingerbankDhcpv6Enterprise',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getDhcpv6Enterprise', to.params.id).then(() => {
        next()
      })
    }
  }
]
