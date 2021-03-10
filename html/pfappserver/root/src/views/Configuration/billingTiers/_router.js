import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/BillingTiersList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_billing_tiers)
    store.registerModule('$_billing_tiers', StoreModule)
  next()
}

export default [
  {
    path: 'billing_tiers',
    name: 'billing_tiers',
    component: TheList,
    props: (route) => ({ query: route.query.query })
  },
  {
    path: 'billing_tiers/new',
    name: 'newBillingTier',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'billing_tier/:id',
    name: 'billing_tier',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_billing_tiers/getBillingTier', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'billing_tier/:id/clone',
    name: 'cloneBillingTier',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_billing_tiers/getBillingTier', to.params.id).then(() => {
        next()
      })
    }
  }
]
