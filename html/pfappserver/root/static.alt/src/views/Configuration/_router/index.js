import store from '@/store'
import ConfigurationView from '../'
import AuthenticationSourcesStore from '../_store/sources'
import BillingTiersStore from '../_store/billingTiers'
import DomainsStore from '../_store/domains'
import FloatingDevicesStore from '../_store/floatingDevices'
import PortalModulesStore from '../_store/portalModules'
import RealmsStore from '../_store/realms'
import RolesStore from '../_store/roles'
import SwitchesStore from '../_store/switches'
import SwitchGroupsStore from '../_store/switchGroups'

const PoliciesAccessControlSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/PoliciesAccessControlSection')
const RolesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/RolesList')
const RoleView = () => import(/* webpackChunkName: "Configuration" */ '../_components/RoleView')
const DomainsTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/DomainsTabs')
const DomainView = () => import(/* webpackChunkName: "Configuration" */ '../_components/DomainView')
const RealmView = () => import(/* webpackChunkName: "Configuration" */ '../_components/RealmView')
const AuthenticationSourcesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/AuthenticationSourcesList')
const AuthenticationSourceView = () => import(/* webpackChunkName: "Configuration" */ '../_components/AuthenticationSourceView')
const NetworkDevicesTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/NetworkDevicesTabs')
const SwitchesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/SwitchesList')
const SwitchView = () => import(/* webpackChunkName: "Configuration" */ '../_components/SwitchView')
const SwitchGroupsList = () => import(/* webpackChunkName: "Configuration" */ '../_components/SwitchGroupsList')
const SwitchGroupView = () => import(/* webpackChunkName: "Configuration" */ '../_components/SwitchGroupView')

const NetworkConfigurationSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/NetworkConfigurationSection')
const FloatingDevicesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/FloatingDevicesList')
const FloatingDeviceView = () => import(/* webpackChunkName: "Configuration" */ '../_components/FloatingDeviceView')
const PortalModulesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/PortalModulesList')
const PortalModuleView = () => import(/* webpackChunkName: "Configuration" */ '../_components/PortalModuleView')

const BillingTiersList = () => import(/* webpackChunkName: "Configuration" */ '../_components/BillingTiersList')
const BillingTierView = () => import(/* webpackChunkName: "Configuration" */ '../_components/BillingTierView')

const route = {
  path: '/configuration',
  name: 'configuration',
  redirect: '/configuration/policesaccesscontrol',
  component: ConfigurationView,
  meta: { transitionDelay: 300 * 2 }, // See _transitions.scss => $slide-bottom-duration
  beforeEnter: (to, from, next) => {
    /**
     * Register Vuex stores
     */
    if (!store.state.$_roles) {
      store.registerModule('$_roles', RolesStore)
    }
    if (!store.state.$_domains) {
      store.registerModule('$_domains', DomainsStore)
    }
    if (!store.state.$_realms) {
      store.registerModule('$_realms', RealmsStore)
    }
    if (!store.state.$_floatingdevices) {
      store.registerModule('$_floatingdevices', FloatingDevicesStore)
    }
    if (!store.state.$_sources) {
      store.registerModule('$_sources', AuthenticationSourcesStore)
    }
    if (!store.state.$_portalmodules) {
      store.registerModule('$_portalmodules', PortalModulesStore)
    }
    if (!store.state.$_billing_tiers) {
      store.registerModule('$_billing_tiers', BillingTiersStore)
    }
    if (!store.state.$_switches) {
      store.registerModule('$_switches', SwitchesStore)
    }
    if (!store.state.$_switchgroups) {
      store.registerModule('$_switchgroups', SwitchGroupsStore)
    }
    next()
  },
  children: [
    /**
     * Policies Access Control
     */
    {
      path: 'policesaccesscontrol',
      component: PoliciesAccessControlSection
    },
    {
      path: 'roles',
      name: 'roles',
      component: RolesList,
      props: (route) => ({ query: route.query.query })
    },
    {
      path: 'roles/new',
      name: 'newRole',
      component: RoleView,
      props: (route) => ({ storeName: '$_roles', isNew: true })
    },
    {
      path: 'role/:id',
      name: 'role',
      component: RoleView,
      props: (route) => ({ storeName: '$_roles', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_roles/getRole', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'domains',
      name: 'domains',
      component: DomainsTabs,
      props: (route) => ({ tab: 'domains', query: route.query.query })
    },
    {
      path: 'domains/new',
      name: 'newDomain',
      component: DomainView,
      props: (route) => ({ storeName: '$_domains', isNew: true })
    },
    {
      path: 'domain/:id',
      name: 'domain',
      component: DomainView,
      props: (route) => ({ storeName: '$_domains', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_domains/getDomain', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'realms',
      name: 'realms',
      component: DomainsTabs,
      props: (route) => ({ tab: 'realms', query: route.query.query })
    },
    {
      path: 'realms/new',
      name: 'newRealm',
      component: RealmView,
      props: (route) => ({ storeName: '$_realms', isNew: true })
    },
    {
      path: 'realm/:id',
      name: 'realm',
      component: RealmView,
      props: (route) => ({ storeName: '$_realms', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_realms/getRealm', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'sources',
      name: 'sources',
      component: AuthenticationSourcesList,
      props: (route) => ({ query: route.query.query })
    },
    {
      path: 'sources/new/:sourceType',
      name: 'newAuthenticationSource',
      component: AuthenticationSourceView,
      props: (route) => ({ storeName: '$_sources', isNew: true, sourceType: route.params.sourceType })
    },
    {
      path: 'source/:id',
      name: 'source',
      component: AuthenticationSourceView,
      props: (route) => ({ storeName: '$_sources', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_sources/getAuthenticationSource', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'source/:id/clone',
      name: 'cloneAuthenticationSource',
      component: AuthenticationSourceView,
      props: (route) => ({ storeName: '$_sources', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_sources/getAuthenticationSource', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'switches',
      name: 'switches',
      component: NetworkDevicesTabs,
      props: (route) => ({ tab: 'switches', query: route.query.query })
    },
    {
      path: 'switches/new',
      name: 'newSwitch',
      component: SwitchView,
      props: (route) => ({ storeName: '$_switches', isNew: true })
    },
    {
      path: 'switch/:id',
      name: 'switch',
      component: SwitchView,
      props: (route) => ({ storeName: '$_switches', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_switches/getSwitch', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'switch_groups',
      name: 'switch_groups',
      component: NetworkDevicesTabs,
      props: (route) => ({ tab: 'switch_groups', query: route.query.query })
    },
    {
      path: 'switch_groups/new',
      name: 'newSwitchGroup',
      component: SwitchGroupView,
      props: (route) => ({ storeName: '$_switch_groups', isNew: true })
    },
    {
      path: 'switch_group/:id',
      name: 'switch_group',
      component: SwitchGroupView,
      props: (route) => ({ storeName: '$_switch_groups', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_switch_groups/getSwitchGroup', to.params.id).then(object => {
          next()
        })
      }
    },
    /**
     * Network Configuration
     */
    {
      path: 'networkconfiguration',
      component: NetworkConfigurationSection
    },
    {
      path: 'floating_devices',
      name: 'floating_devices',
      component: FloatingDevicesList,
      props: (route) => ({ query: route.query.query })
    },
    {
      path: 'floating_devices/new',
      name: 'newFloatingDevice',
      component: FloatingDeviceView,
      props: (route) => ({ storeName: '$_floatingdevices', isNew: true })
    },
    {
      path: 'floating_device/:id',
      name: 'floating_device',
      component: FloatingDeviceView,
      props: (route) => ({ storeName: '$_floatingdevices', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_floatingdevices/getFloatingDevice', to.params.id).then(object => {
          next()
        })
      }
    },
    /**
     *  Advanced Access Configuration
     */
    {
      path: 'portal_modules',
      name: 'portal_modules',
      component: PortalModulesList,
      props: (route) => ({ storeName: '$_portalmodules', query: route.query.query })
    },
    {
      path: 'portal_modules/new/:type',
      name: 'newPortalModule',
      component: PortalModuleView,
      props: (route) => ({ storeName: '$_portalmodules', isNew: true, moduleType: route.params.type }),
      beforeEnter: (to, from, next) => {
        store.dispatch('config/getSources').then(object => {
          next()
        })
      }
    },
    {
      path: 'portal_module/:id',
      name: 'portal_module',
      component: PortalModuleView,
      props: (route) => ({ storeName: '$_portalmodules', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_portalmodules/getPortalModule', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'portal_module/:id/clone',
      name: 'clonePortalModule',
      component: PortalModuleView,
      props: (route) => ({ storeName: '$_portalmodules', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_portalmodules/getPortalModule', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'billing_tiers',
      name: 'billing_tiers',
      component: BillingTiersList,
      props: (route) => ({ query: route.query.query })
    },
    {
      path: 'billing_tiers/new',
      name: 'newBillingTier',
      component: BillingTierView,
      props: (route) => ({ storeName: '$_billing_tiers', isNew: true })
    },
    {
      path: 'billing_tier/:id',
      name: 'billing_tier',
      component: BillingTierView,
      props: (route) => ({ storeName: '$_billing_tiers', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_billing_tiers/getBillingTier', to.params.id).then(object => {
          next()
        })
      }
    }
  ]
}

export default route
