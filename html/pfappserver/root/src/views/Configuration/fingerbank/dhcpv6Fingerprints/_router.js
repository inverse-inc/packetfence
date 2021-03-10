import store from '@/store'
import { TheTabs } from '../_components/'
const TheView = () => import(/* webpackChunkName: "Fingerbank" */ './_components/TheView')

export default [
  {
    path: 'fingerbank/dhcpv6_fingerprints',
    name: 'fingerbankDhcpv6Fingerprints',
    component: TheTabs,
    props: (route) => ({ tab: 'dhcpv6_fingerprints', query: route.query.query })
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
