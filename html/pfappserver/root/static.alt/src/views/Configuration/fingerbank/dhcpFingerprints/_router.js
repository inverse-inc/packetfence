import store from '@/store'
import { TheTabs } from '../_components/'
const TheView = () => import(/* webpackChunkName: "Fingerbank" */ './_components/TheView')

export default [
  {
    path: 'fingerbank/dhcp_fingerprints',
    name: 'fingerbankDhcpFingerprints',
    component: TheTabs,
    props: (route) => ({ tab: 'dhcp_fingerprints', query: route.query.query })
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
