import store from '@/store'

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'fingerbankDhcpv6Fingerprints' }),
    goToItem: params => $router
      .push({ name: 'fingerbankDhcpv6Fingerprint', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneFingerbankDhcpv6Fingerprint', params }),
    goToNew: params => $router.push({ name: 'newFingerbankDhcpv6Fingerprint', params })
  }
}

import { TheTabs } from '../_components/'
const TheView = () => import(/* webpackChunkName: "Fingerbank" */ './_components/TheView')

export default [
  {
    path: 'fingerbank/dhcpv6_fingerprints',
    name: 'fingerbankDhcpv6Fingerprints',
    component: TheTabs,
    props: () => ({ tab: 'fingerbankDhcpv6Fingerprints', scope: 'all' })
  },
  {
    path: 'fingerbank/:scope/dhcpv6_fingerprints',
    name: 'fingerbankDhcpv6FingerprintsByScope',
    component: TheTabs,
    props: (route) => ({ tab: 'fingerbankDhcpv6Fingerprints', scope: route.params.scope })
  },
  {
    path: 'fingerbank/:scope/dhcpv6_fingerprints/new',
    name: 'newFingerbankDhcpv6Fingerprint',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, isNew: true })
  },
  {
    path: 'fingerbank/:scope/dhcpv6_fingerprint/:id',
    name: 'fingerbankDhcpv6Fingerprint',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, id: route.params.id }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getDhcpv6Fingerprint', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'fingerbank/:scope/dhcpv6_fingerprint/:id/clone',
    name: 'cloneFingerbankDhcpv6Fingerprint',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getDhcpv6Fingerprint', to.params.id).then(() => {
        next()
      })
    }
  }
]
