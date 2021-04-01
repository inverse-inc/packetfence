import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ './_components/TheList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_tenants)
    store.registerModule('$_tenants', StoreModule)
  next()
}

export default [
  {
    path: 'tenants',
    name: 'tenants',
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter
  },
  {
    path: 'tenants/new',
    name: 'newTenant',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'tenant/:id',
    name: 'tenant',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_tenants/getTenant', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'tenant/:id/clone',
    name: 'cloneTenant',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_tenants/getTenant', to.params.id).then(() => {
        next()
      })
    }
  }
]
