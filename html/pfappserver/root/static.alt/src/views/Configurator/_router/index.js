import store from '@/store'
import FormStore from '@/store/base/form'

import ConfiguratorView from '../'

import BasesStore from '@/views/Configuration/bases/_store'
import InterfacesStore from '@/views/Configuration/networks/interfaces/_store/'
import FingerbankStore from '@/views/Configuration/fingerbank/_store'
// import StatusStore from '@/views/Status/_store'
import UsersStore from '@/views/Users/_store'

const InterfacesList = () => import(/* webpackChunkName: "Configurator" */ '../_components/InterfacesList')
const InterfaceView = () => import(/* webpackChunkName: "Configurator" */ '../_components/InterfaceView')
const NetworkStep = () => import(/* webpackChunkName: "Configurator" */ '../_components/NetworkStep')
const PacketFenceStep = () => import(/* webpackChunkName: "Configurator" */ '../_components/PacketFenceStep')
const FingerbankStep = () => import(/* webpackChunkName: "Configurator" */ '../_components/FingerbankStep')
const StatusStep = () => import(/* webpackChunkName: "Configurator" */ '../_components/StatusStep')

const route = {
  path: '/configurator',
  name: 'configurator',
  redirect: '/configurator/network/interfaces',
  component: ConfiguratorView,
  meta: {
    transitionDelay: 150 // force scroll to the top
  },
  beforeEnter: (to, from, next) => {
    // do not include X-PacketFence-Tenant-Id header when in configrator, fixes #5610
    if (localStorage.getItem('X-PacketFence-Tenant-Id')) {
      localStorage.removeItem('X-PacketFence-Tenant-Id')
    }
    // Force initial visit to start with the first step
    if (!['configurator-network', 'configurator-interfaces'].includes(to.name)) {
      next({ name: 'configurator-network'})
    } else {
      next()
    }
  },
  children: [
    {
      path: 'network',
      name: 'configurator-network',
      redirect: '/configurator/network/interfaces',
      component: NetworkStep,
      beforeEnter: (to, from, next) => {
        if (!store.state.$_interfaces) {
          store.registerModule('$_interfaces', InterfacesStore) // required by InterfacesList and InterfaceView
        }
        if (!store.state.formInterface) {
          store.registerModule('formInterface', FormStore) // required by InterfaceView
        }
        if (!store.state.formNetwork) {
          store.registerModule('formNetwork', FormStore) // required by NetworkStep
        }
        next()
      },
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
            store.dispatch('$_interfaces/getInterface', to.params.id).then(() => {
              next()
            })
          }
        },
        {
          path: 'interface/:id/clone',
          name: 'configurator-cloneInterface',
          component: InterfaceView,
          props: (route) => ({ formStoreName: 'formInterface', id: route.params.id, isClone: true }),
          beforeEnter: (to, from, next) => {
            store.dispatch('$_interfaces/getInterface', to.params.id).then(() => {
              next()
            })
          }
        },
        {
          path: 'interface/:id/new',
          name: 'configurator-newInterface',
          component: InterfaceView,
          props: (route) => ({ formStoreName: 'formInterface', id: route.params.id, isNew: true }),
          beforeEnter: (to, from, next) => {
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
      beforeEnter: (to, from, next) => {
        if (!store.state.$_bases) {
          store.registerModule('$_bases', BasesStore) // required by GeneralView
        }
        if (!store.state.$_users) {
          store.registerModule('$_users', UsersStore) // required by AdministratorView
        }
        if (!store.state.formPacketFence) { // common form store for all view components of this step
          store.registerModule('formPacketFence', FormStore)
        }
        next()
      }
    },
    {
      path: 'fingerbank',
      name: 'configurator-fingerbank',
      component: FingerbankStep,
      beforeEnter: (to, from, next) => {
        if (!store.state.$_fingerbank) {
          store.registerModule('$_fingerbank', FingerbankStore) // required by FingerbankView
        }
        if (!store.state.formFingerbank) {
          store.registerModule('formFingerbank', FormStore) // required by FingerbankView
        }
        next()
      }
    },
    {
      path: 'status',
      name: 'configurator-status',
      component: StatusStep,
      beforeEnter: (to, from, next) => {
        if (!store.state.$_bases) {
          store.registerModule('$_bases', BasesStore) // required by GeneralView
        }
        // if (!store.state.$_status) {
        //   store.registerModule('$_status', StatusStore) // required by ServicesView
        // }
        next()
      }
    }
  ]
}

export default route
