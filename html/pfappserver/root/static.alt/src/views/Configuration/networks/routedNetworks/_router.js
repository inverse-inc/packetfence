import store from '@/store'
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export default [
  {
    path: 'interfaces/routed_networks/new',
    name: 'newRoutedNetwork',
    component: TheView,
    props: () => ({ isNew: true })
  },
  {
    path: 'interfaces/routed_network/:id',
    name: 'routed_network',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_routed_networks/getRoutedNetwork', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'interfaces/routed_network/:id/clone',
    name: 'cloneRoutedNetwork',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      store.dispatch('$_routed_networks/getRoutedNetwork', to.params.id).then(() => {
        next()
      })
    }
  }
]
