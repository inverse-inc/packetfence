import store from '@/store'
import InterfacesStoreModule from '@/views/Configuration/networks/interfaces/_store'

const TheStep = () => import(/* webpackChunkName: "Configurator" */ './_components/TheStep')
const TheList = () => import(/* webpackChunkName: "Configurator" */ '../_components/InterfacesList')
const TheView = () => import(/* webpackChunkName: "Configurator" */ '@/views/Configuration/networks/interfaces/_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_interfaces)
    store.registerModule('$_interfaces', InterfacesStoreModule)
  next()
}

// prefix collection router name(s) in Configuration/networks/interfaces
const prefixRouteName = 'configurator-'

export default [
  {
    path: 'network',
    name: 'configurator-network',
    redirect: '/configurator/network/interfaces',
    component: TheStep,
    beforeEnter,
    children: [
      {
        path: 'interfaces',
        name: 'configurator-interfaces',
        component: TheList,
      },
      {
        path: 'interface/:id',
        name: 'configurator-interface',
        component: TheView,
        props: (route) => ({ prefixRouteName, id: route.params.id }),
        beforeEnter: (to, from, next) => {
          store.dispatch('$_interfaces/getInterface', to.params.id).then(() => {
            next()
          })
        }
      },
      {
        path: 'interface/:id/clone',
        name: 'configurator-cloneInterface',
        component: TheView,
        props: (route) => ({ prefixRouteName, id: route.params.id, isClone: true }),
        beforeEnter: (to, from, next) => {
          store.dispatch('$_interfaces/getInterface', to.params.id).then(() => {
            next()
          })
        }
      },
      {
        path: 'interface/:id/new',
        name: 'configurator-newInterface',
        component: TheView,
        props: (route) => ({ prefixRouteName, id: route.params.id, isNew: true }),
        beforeEnter: (to, from, next) => {
          store.dispatch('$_interfaces/getInterface', to.params.id).then(() => {
            next()
          })
        }
      }
    ]
  }
]
