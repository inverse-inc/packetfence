import store from '@/store'

export const useRouter = $router => {
  return {
    goToCollection: () => $router.push({ name: 'fingerbankDhcpFingerprints' }),
    goToItem: params => $router
      .push({ name: 'fingerbankDhcpFingerprint', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneFingerbankDhcpFingerprint', params }),
    goToNew: params => $router.push({ name: 'newFingerbankDhcpFingerprint', params })
  }
}

import { TheTabs } from '../_components/'
const TheView = () => import(/* webpackChunkName: "Fingerbank" */ './_components/TheView')

export default [
  {
    path: 'fingerbank/dhcp_fingerprints',
    name: 'fingerbankDhcpFingerprints',
    component: TheTabs,
    props: () => ({ tab: 'fingerbankDhcpFingerprints', scope: 'all' })
  },
  {
    path: 'fingerbank/:scope/dhcp_fingerprints',
    name: 'fingerbankDhcpFingerprintsByScope',
    component: TheTabs,
    props: (route) => ({ tab: 'fingerbankDhcpFingerprints', scope: route.params.scope })
  },
  {
    path: 'fingerbank/:scope/dhcp_fingerprints/new',
    name: 'newFingerbankDhcpFingerprint',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, isNew: true })
  },
  {
    path: 'fingerbank/:scope/dhcp_fingerprint/:id',
    name: 'fingerbankDhcpFingerprint',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, id: route.params.id }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getDhcpFingerprint', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'fingerbank/:scope/dhcp_fingerprint/:id/clone',
    name: 'cloneFingerbankDhcpFingerprint',
    component: TheView,
    props: (route) => ({ scope: route.params.scope, id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_fingerbank/getDhcpFingerprint', to.params.id).then(() => {
        next()
      })
    }
  },
]
