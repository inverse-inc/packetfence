import store from '@/store'
const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../../_components/NetworksTabs')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export default [
  {
    path: 'interfaces',
    name: 'interfaces',
    component: TheTabs,
    props: (route) => ({ tab: 'interfaces', query: route.query.query })
  },
  {
    path: 'interface/:id',
    name: 'interface',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_interfaces/getInterface', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'interface/:id/clone',
    name: 'cloneInterface',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_interfaces/getInterface', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'interface/:id/new',
    name: 'newInterface',
    component: TheView,
    props: (route) => ({ id: route.params.id, isNew: true }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_interfaces/getInterface', to.params.id).then(() => {
        next()
      })
    }
  }
]
