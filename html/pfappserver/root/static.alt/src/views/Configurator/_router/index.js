import store from '@/store'
import FormStore from '@/store/base/form'

import ConfiguratorView from '../'

import BasesStore from '@/views/Configuration/_store/bases'
import InterfacesStore from '@/views/Configuration/_store/interfaces'

const InterfacesList = () => import(/* webpackChunkName: "Configurator" */ '../_components/InterfacesList')
const InterfaceView = () => import(/* webpackChunkName: "Configurator" */ '../_components/InterfaceView')
const NetworkStep = () => import(/* webpackChunkName: "Configurator" */ '../_components/NetworkStep')
const PacketFenceStep = () => import(/* webpackChunkName: "Configurator" */ '../_components/PacketFenceStep')

const route = {
  path: '/configurator',
  name: 'configurator',
  redirect: '/configurator/network/interfaces',
  component: ConfiguratorView,
  beforeEnter: (to, from, next) => {
    /**
     * Register Vuex stores
     */
    if (!store.state.$_interfaces) {
      store.registerModule('$_interfaces', InterfacesStore)
    }
    if (!store.state.$_bases) {
      store.registerModule('$_bases', BasesStore)
    }
    next()
  },
  children: [
    {
      path: 'network',
      name: 'configurator-network',
      redirect: '/configurator/network/interfaces',
      component: NetworkStep,
      children: [
        {
          path: 'interfaces',
          name: 'configurator-interfaces',
          component: InterfacesList
        },
        {
          path: 'interface/:id',
          name: 'configurator-interface',
          component: InterfaceView,
          props: (route) => ({ formStoreName: 'formInterface', id: route.params.id }),
          beforeEnter: (to, from, next) => {
            if (!store.state.formInterface) { // Register store module only once
              store.registerModule('formInterface', FormStore)
            }
            store.dispatch('$_interfaces/getInterface', to.params.id).then(() => {
              next()
            })
          }
        }
      ]
    },
    {
      path: 'packetfence',
      name: 'configurator-packetfence',
      component: PacketFenceStep,
      children: [

      ]
    }
  ]
}

export default route
