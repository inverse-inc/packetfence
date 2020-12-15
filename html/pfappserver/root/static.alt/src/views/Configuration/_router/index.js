import acl from '@/utils/acl'
import store from '@/store'
import FormStore from '@/store/base/form'
import ConfigurationView from '../'
import AdminRolesStore from '../_store/adminRoles'
import BasesStore from '../_store/bases'
import BillingTiersStore from '../_store/billingTiers'
import ConnectionProfilesStore from '../_store/connectionProfiles'
import FloatingDevicesStore from '../_store/floatingDevices'
import PkisStore from '../pki/_store'
import PortalModulesStore from '../_store/portalModules'
import RadiusEapStore from '../_store/radiusEap'
import RadiusFastStore from '../_store/radiusFast'
import RadiusOcspStore from '../_store/radiusOcsp'
import RadiusSslStore from '../_store/radiusSsl'
import RadiusTlsStore from '../_store/radiusTls'
import SyslogForwardersStore from '../_store/syslogForwarders'
import WrixLocationsStore from '../_store/wrixLocations'



/* Policies Access Control */
const PoliciesAccessControlSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/PoliciesAccessControlSection')
import RolesRoutes from '../roles/_router'
import DomainsRoutes from '../domains/_router'
import RealmsRoutes from '../realms/_router'
import SourcesRoutes from '../sources/_router'
import SwitchesRoutes from '../switches/_router'
import SwitchGroupsRoutes from '../switchGroups/_router'
const ConnectionProfilesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/ConnectionProfilesList')
const ConnectionProfileView = () => import(/* webpackChunkName: "Configuration" */ '../_components/ConnectionProfileView')
const ConnectionProfileFileView = () => import(/* webpackChunkName: "Editor" */ '../_components/ConnectionProfileFileView')

/* Compliance */
const ComplianceSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/ComplianceSection')
import FingerbankRoutes from '../fingerbank/_router'
import NetworkBehaviorPoliciesRoutes from '../networkBehaviorPolicy/_router'
import ScanEnginesRoutes from '../scanEngines/_router'
import SecurityEventsRoutes from '../securityEvents/_router'
import WmiRulesRoutes from '../wmiRules/_router'

/* Integration */
const IntegrationSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/IntegrationSection')
import FirewallsRoutes from '../firewalls/_router'
import CiscoMobilityServicesEngineRoutes from '../ciscoMobilityServicesEngine/_router'
import WebServicesRoutes from '../webServices/_router'
import SwitchTemplatesRoutes from '../switchTemplates/_router'
import SyslogParsersRoutes from '../syslogParsers/_router'
const SyslogForwardersList = () => import(/* webpackChunkName: "Configuration" */ '../_components/SyslogForwardersList')
const SyslogForwarderView = () => import(/* webpackChunkName: "Configuration" */ '../_components/SyslogForwarderView')
const WrixLocationsList = () => import(/* webpackChunkName: "Configuration" */ '../_components/WrixLocationsList')
const WrixLocationView = () => import(/* webpackChunkName: "Configuration" */ '../_components/WrixLocationView')
const PkisTabs = () => import(/* webpackChunkName: "Pki" */ '../_components/PkisTabs')
const PkiCaView = () => import(/* webpackChunkName: "Pki" */ '../_components/PkiCaView')
const PkiProfileView = () => import(/* webpackChunkName: "Pki" */ '../_components/PkiProfileView')
const PkiCertView = () => import(/* webpackChunkName: "Pki" */ '../_components/PkiCertView')
const PkiRevokedCertView = () => import(/* webpackChunkName: "Pki" */ '../_components/PkiRevokedCertView')

/* Advanced Access Configuration */
const AdvancedAccessConfigurationSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/AdvancedAccessConfigurationSection')
const CaptivePortalView = () => import(/* webpackChunkName: "Configuration" */ '../_components/CaptivePortalView')
import FilterEnginesRoutes from '../filterEngines/_router'
const BillingTiersList = () => import(/* webpackChunkName: "Configuration" */ '../_components/BillingTiersList')
const BillingTierView = () => import(/* webpackChunkName: "Configuration" */ '../_components/BillingTierView')
import PkiProvidersRoutes from '../pkiProviders/_router'
const PortalModulesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/PortalModulesList')
const PortalModuleView = () => import(/* webpackChunkName: "Configuration" */ '../_components/PortalModuleView')
import AccessDurationsRoutes from '../accessDurations/_router'
import ProvisionersRoutes from '../provisioners/_router'
import SelfServicesRoutes from '../selfServices/_router'

/* Network Configuration */
const NetworkConfigurationSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/NetworkConfigurationSection')
import NetworksRoutes from '../networks/_router'
const SnmpTrapView = () => import(/* webpackChunkName: "Configuration" */ '../_components/SnmpTrapView')
const FloatingDevicesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/FloatingDevicesList')
const FloatingDeviceView = () => import(/* webpackChunkName: "Configuration" */ '../_components/FloatingDeviceView')
import SslCertificatesRoutes from '../sslCertificates/_router'

/* System Configuration */
const SystemConfigurationSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/SystemConfigurationSection')
export const MainTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/MainTabs')
import AdvancedRoutes from '../advanced/_router'
import MaintenanceTasksRoutes from '../maintenanceTasks/_router'
const DatabaseTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/DatabaseTabs')
import ActiveActiveRoutes from '../activeActive/_router'
const RadiusTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/RadiusTabs')
const RadiusEapView = () => import(/* webpackChunkName: "Configuration" */ '../_components/RadiusEapView')
const RadiusTlsView = () => import(/* webpackChunkName: "Configuration" */ '../_components/RadiusTlsView')
const RadiusFastView = () => import(/* webpackChunkName: "Configuration" */ '../_components/RadiusFastView')
const RadiusSslView = () => import(/* webpackChunkName: "Configuration" */ '../_components/RadiusSslView')
const RadiusOcspView = () => import(/* webpackChunkName: "Configuration" */ '../_components/RadiusOcspView')
const DnsView = () => import(/* webpackChunkName: "Configuration" */ '../_components/DnsView')
const AdminRolesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/AdminRolesList')
const AdminRoleView = () => import(/* webpackChunkName: "Configuration" */ '../_components/AdminRoleView')

const route = {
  path: '/configuration',
  name: 'configuration',
  redirect: '/configuration/policies_access_control',
  component: ConfigurationView,
  meta: {
    can: () => acl.$can('read', 'configuration_main'), // has ACL for 1+ children
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  beforeEnter: (to, from, next) => {
    /**
     * Register Vuex stores
     */
    if (!store.state.$_admin_roles) {
      store.registerModule('$_admin_roles', AdminRolesStore)
    }
    if (!store.state.$_bases) {
      store.registerModule('$_bases', BasesStore)
    }
    if (!store.state.$_billing_tiers) {
      store.registerModule('$_billing_tiers', BillingTiersStore)
    }
    if (!store.state.$_connection_profiles) {
      store.registerModule('$_connection_profiles', ConnectionProfilesStore)
    }
    if (!store.state.$_floatingdevices) {
      store.registerModule('$_floatingdevices', FloatingDevicesStore)
    }
    if (!store.state.$_pkis) {
      store.registerModule('$_pkis', PkisStore)
    }
    if (!store.state.$_portalmodules) {
      store.registerModule('$_portalmodules', PortalModulesStore)
    }
    if (!store.state.$_radius_eap) {
      store.registerModule('$_radius_eap', RadiusEapStore)
    }
    if (!store.state.$_radius_fast) {
      store.registerModule('$_radius_fast', RadiusFastStore)
    }
    if (!store.state.$_radius_ocsp) {
      store.registerModule('$_radius_ocsp', RadiusOcspStore)
    }
    if (!store.state.$_radius_ssl) {
      store.registerModule('$_radius_ssl', RadiusSslStore)
    }
    if (!store.state.$_radius_tls) {
      store.registerModule('$_radius_tls', RadiusTlsStore)
    }
    if (!store.state.$_syslog_forwarders) {
      store.registerModule('$_syslog_forwarders', SyslogForwardersStore)
    }
    if (!store.state.$_wrix_locations) {
      store.registerModule('$_wrix_locations', WrixLocationsStore)
    }
    next()
  },
  children: [
    /**
     * Policies Access Control
     */
    {
      path: 'policies_access_control',
      component: PoliciesAccessControlSection
    },
    ...RolesRoutes,
    ...DomainsRoutes,
    ...RealmsRoutes,
    ...SourcesRoutes,
    ...SwitchesRoutes,
    ...SwitchGroupsRoutes,
    {
      path: 'connection_profiles',
      name: 'connection_profiles',
      component: ConnectionProfilesList,
      props: (route) => ({ query: route.query.query })
    },
    {
      path: 'connection_profiles/new',
      name: 'newConnectionProfile',
      component: ConnectionProfileView,
      props: () => ({ formStoreName: 'formConnectionProfile', isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formConnectionProfile) { // Register store module only once
          store.registerModule('formConnectionProfile', FormStore)
        }
        next()
      }
    },
    {
      path: 'connection_profile/:id',
      name: 'connection_profile',
      component: ConnectionProfileView,
      props: (route) => ({ formStoreName: 'formConnectionProfile', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formConnectionProfile) { // Register store module only once
          store.registerModule('formConnectionProfile', FormStore)
        }
        store.dispatch('$_connection_profiles/getConnectionProfile', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'connection_profile/:id/clone',
      name: 'cloneConnectionProfile',
      component: ConnectionProfileView,
      props: (route) => ({ formStoreName: 'formConnectionProfile', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formConnectionProfile) { // Register store module only once
          store.registerModule('formConnectionProfile', FormStore)
        }
        store.dispatch('$_connection_profiles/getConnectionProfile', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'connection_profile/:id/files',
      name: 'connectionProfileFiles',
      component: ConnectionProfileView,
      props: (route) => ({ formStoreName: 'formConnectionProfile', id: route.params.id, tabIndex: 2 }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formConnectionProfile) { // Register store module only once
          store.registerModule('formConnectionProfile', FormStore)
        }
        store.dispatch('$_connection_profiles/getConnectionProfile', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'connection_profile/:id/files/:path/new',
      name: 'newConnectionProfileFile',
      component: ConnectionProfileFileView,
      props: (route) => ({ formStoreName: 'formConnectionProfile', id: route.params.id, filename: route.params.path, isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formConnectionProfile) { // Register store module only once
          store.registerModule('formConnectionProfile', FormStore)
        }
        next()
      }
    },
    {
      path: 'connection_profile/:id/files/:filename',
      name: 'connectionProfileFile',
      component: ConnectionProfileFileView,
      props: (route) => ({ formStoreName: 'formConnectionProfile', id: route.params.id, filename: route.params.filename }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formConnectionProfile) { // Register store module only once
          store.registerModule('formConnectionProfile', FormStore)
        }
        next()
      }
    },
    /**
     * Compliance
     */

    {
      path: 'compliance',
      component: ComplianceSection
    },
    ...FingerbankRoutes,
    ...NetworkBehaviorPoliciesRoutes,
    ...ScanEnginesRoutes,
    ...SecurityEventsRoutes,
    ...WmiRulesRoutes,
    /**
     * Integration
     */
    {
      path: 'integration',
      component: IntegrationSection
    },
    ...FirewallsRoutes,
    ...CiscoMobilityServicesEngineRoutes,
    ...WebServicesRoutes,
    ...SwitchTemplatesRoutes,
    ...SyslogParsersRoutes,
    {
      path: 'syslog',
      name: 'syslogForwarders',
      component: SyslogForwardersList,
      props: (route) => ({ query: route.query.query })
    },
    {
      path: 'syslog/new/:syslogForwarderType',
      name: 'newSyslogForwarder',
      component: SyslogForwarderView,
      props: (route) => ({ formStoreName: 'formSyslogForwarders', isNew: true, syslogForwarderType: route.params.syslogForwarderType }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formSyslogForwarders) { // Register store module only once
          store.registerModule('formSyslogForwarders', FormStore)
        }
        next()
      }
    },
    {
      path: 'syslog/:id',
      name: 'syslogForwarder',
      component: SyslogForwarderView,
      props: (route) => ({ formStoreName: 'formSyslogForwarders', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formSyslogForwarders) { // Register store module only once
          store.registerModule('formSyslogForwarders', FormStore)
        }
        store.dispatch('$_syslog_forwarders/getSyslogForwarder', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'syslog/:id/clone',
      name: 'cloneSyslogForwarder',
      component: SyslogForwarderView,
      props: (route) => ({ formStoreName: 'formSyslogForwarders', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formSyslogForwarders) { // Register store module only once
          store.registerModule('formSyslogForwarders', FormStore)
        }
        store.dispatch('$_syslog_forwarders/getSyslogForwarder', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'wrix',
      name: 'wrixLocations',
      component: WrixLocationsList,
      props: (route) => ({ query: route.query.query })
    },
    {
      path: 'wrix/new',
      name: 'newWrixLocation',
      component: WrixLocationView,
      props: () => ({ formStoreName: 'formWrixLocation', isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formWrixLocation) { // Register store module only once
          store.registerModule('formWrixLocation', FormStore)
        }
        next()
      }
    },
    {
      path: 'wrix/:id',
      name: 'wrixLocation',
      component: WrixLocationView,
      props: (route) => ({ formStoreName: 'formWrixLocation', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formWrixLocation) { // Register store module only once
          store.registerModule('formWrixLocation', FormStore)
        }
        store.dispatch('$_wrix_locations/getWrixLocation', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'wrix/:id/clone',
      name: 'cloneWrixLocation',
      component: WrixLocationView,
      props: (route) => ({ formStoreName: 'formWrixLocation', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formWrixLocation) { // Register store module only once
          store.registerModule('formWrixLocation', FormStore)
        }
        store.dispatch('$_wrix_locations/getWrixLocation', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'pki',
      name: 'pki',
      component: PkisTabs,
      props: (route) => ({ tab: 'pkiCas', query: route.query.query })
    },
    {
      path: 'pki/cas',
      name: 'pkiCas',
      component: PkisTabs,
      props: (route) => ({ tab: 'pkiCas', query: route.query.query })
    },
    {
      path: 'pki/cas/new',
      name: 'newPkiCa',
      component: PkiCaView,
      props: () => ({ formStoreName: 'formPkiCa', isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formPkiCa) { // Register store module only once
          store.registerModule('formPkiCa', FormStore)
        }
        next()
      }
    },
    {
      path: 'pki/ca/:id',
      name: 'pkiCa',
      component: PkiCaView,
      props: (route) => ({ formStoreName: 'formPkiCa', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formPkiCa) { // Register store module only once
          store.registerModule('formPkiCa', FormStore)
        }
        store.dispatch('$_pkis/getCa', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'pki/ca/:id/clone',
      name: 'clonePkiCa',
      component: PkiCaView,
      props: (route) => ({ formStoreName: 'formPkiCa', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formPkiCa) { // Register store module only once
          store.registerModule('formPkiCa', FormStore)
        }
        store.dispatch('$_pkis/getCa', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'pki/profiles',
      name: 'pkiProfiles',
      component: PkisTabs,
      props: (route) => ({ tab: 'pkiProfiles', query: route.query.query })
    },
    {
      path: 'pki/ca/:ca_id/profiles/new',
      name: 'newPkiProfile',
      component: PkiProfileView,
      props: (route) => ({ formStoreName: 'formPkiProfile', ca_id: String(route.params.ca_id).toString(), isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formPkiProfile) { // Register store module only once
          store.registerModule('formPkiProfile', FormStore)
        }
        next()
      }
    },
    {
      path: 'pki/profile/:id',
      name: 'pkiProfile',
      component: PkiProfileView,
      props: (route) => ({ formStoreName: 'formPkiProfile', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formPkiProfile) { // Register store module only once
          store.registerModule('formPkiProfile', FormStore)
        }
        store.dispatch('$_pkis/getProfile', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'pki/profile/:id/clone',
      name: 'clonePkiProfile',
      component: PkiProfileView,
      props: (route) => ({ formStoreName: 'formPkiProfile', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formPkiProfile) { // Register store module only once
          store.registerModule('formPkiProfile', FormStore)
        }
        store.dispatch('$_pkis/getProfile', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'pki/certs',
      name: 'pkiCerts',
      component: PkisTabs,
      props: (route) => ({ tab: 'pkiCerts', query: route.query.query })
    },
    {
      path: 'pki/profile/:profile_id/certs/new',
      name: 'newPkiCert',
      component: PkiCertView,
      props: (route) => ({ formStoreName: 'formPkiCert', profile_id: String(route.params.profile_id).toString(), isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formPkiCert) { // Register store module only once
          store.registerModule('formPkiCert', FormStore)
        }
        next()
      }
    },
    {
      path: 'pki/cert/:id',
      name: 'pkiCert',
      component: PkiCertView,
      props: (route) => ({ formStoreName: 'formPkiCert', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formPkiCert) { // Register store module only once
          store.registerModule('formPkiCert', FormStore)
        }
        store.dispatch('$_pkis/getCert', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'pki/cert/:id/clone',
      name: 'clonePkiCert',
      component: PkiCertView,
      props: (route) => ({ formStoreName: 'formPkiCert', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formPkiCert) { // Register store module only once
          store.registerModule('formPkiCert', FormStore)
        }
        store.dispatch('$_pkis/getCert', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'pki/revokedcerts',
      name: 'pkiRevokedCerts',
      component: PkisTabs,
      props: (route) => ({ tab: 'pkiRevokedCerts', query: route.query.query })
    },
    {
      path: 'pki/revokedcert/:id',
      name: 'pkiRevokedCert',
      component: PkiRevokedCertView,
      props: (route) => ({ formStoreName: 'formPkiCert', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formPkiCert) { // Register store module only once
          store.registerModule('formPkiCert', FormStore)
        }
        store.dispatch('$_pkis/getRevokedCert', to.params.id).then(() => {
          next()
        })
      }
    },
    /**
     *  Advanced Access Configuration
     */
    {
      path: 'advanced_access_configuration',
      component: AdvancedAccessConfigurationSection
    },
    ...FilterEnginesRoutes,
    {
      path: 'captive_portal',
      name: 'captive_portal',
      component: CaptivePortalView,
      props: (route) => ({ formStoreName: 'formCaptivePortal', query: route.query.query }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formCaptivePortal) { // Register store module only once
          store.registerModule('formCaptivePortal', FormStore)
        }
        next()
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
      props: () => ({ formStoreName: 'formBillingTier', isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formBillingTier) { // Register store module only once
          store.registerModule('formBillingTier', FormStore)
        }
        next()
      }
    },
    {
      path: 'billing_tier/:id',
      name: 'billing_tier',
      component: BillingTierView,
      props: (route) => ({ formStoreName: 'formBillingTier', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formBillingTier) { // Register store module only once
          store.registerModule('formBillingTier', FormStore)
        }
        store.dispatch('$_billing_tiers/getBillingTier', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'billing_tier/:id/clone',
      name: 'cloneBillingTier',
      component: BillingTierView,
      props: (route) => ({ formStoreName: 'formBillingTier', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formBillingTier) { // Register store module only once
          store.registerModule('formBillingTier', FormStore)
        }
        store.dispatch('$_billing_tiers/getBillingTier', to.params.id).then(() => {
          next()
        })
      }
    },
    ...PkiProvidersRoutes,
    ...ProvisionersRoutes,
    {
      path: 'portal_modules',
      name: 'portal_modules',
      component: PortalModulesList,
      props: (route) => ({ query: route.query.query })
    },
    {
      path: 'portal_modules/new/:moduleType',
      name: 'newPortalModule',
      component: PortalModuleView,
      props: (route) => ({ formStoreName: 'formPortalModule', isNew: true, moduleType: route.params.moduleType }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formPortalModule) { // Register store module only once
          store.registerModule('formPortalModule', FormStore)
        }
        next()
      }
    },
    {
      path: 'portal_module/:id',
      name: 'portal_module',
      component: PortalModuleView,
      props: (route) => ({ formStoreName: 'formPortalModule', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formPortalModule) { // Register store module only once
          store.registerModule('formPortalModule', FormStore)
        }
        store.dispatch('$_portalmodules/getPortalModule', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'portal_module/:id/clone',
      name: 'clonePortalModule',
      component: PortalModuleView,
      props: (route) => ({ formStoreName: 'formPortalModule', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formPortalModule) { // Register store module only once
          store.registerModule('formPortalModule', FormStore)
        }
        store.dispatch('$_portalmodules/getPortalModule', to.params.id).then(() => {
          next()
        })
      }
    },
    ...AccessDurationsRoutes,
    ...SelfServicesRoutes,

    /**
     * Network Configuration
     */
    {
      path: 'network_configuration',
      component: NetworkConfigurationSection
    },
    ...NetworksRoutes,
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
      props: () => ({ formStoreName: 'formFloatingDevice', isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formFloatingDevice) { // Register store module only once
          store.registerModule('formFloatingDevice', FormStore)
        }
        next()
      }
    },
    {
      path: 'floating_device/:id',
      name: 'floating_device',
      component: FloatingDeviceView,
      props: (route) => ({ formStoreName: 'formFloatingDevice', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formFloatingDevice) { // Register store module only once
          store.registerModule('formFloatingDevice', FormStore)
        }
        store.dispatch('$_floatingdevices/getFloatingDevice', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'floating_device/:id/clone',
      name: 'cloneFloatingDevice',
      component: FloatingDeviceView,
      props: (route) => ({ formStoreName: 'formFloatingDevice', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formFloatingDevice) { // Register store module only once
          store.registerModule('formFloatingDevice', FormStore)
        }
        store.dispatch('$_floatingdevices/getFloatingDevice', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'snmp_traps',
      name: 'snmp_traps',
      component: SnmpTrapView,
      props: (route) => ({ formStoreName: 'formSnmpTrap', query: route.query.query }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formSnmpTrap) { // Register store module only once
          store.registerModule('formSnmpTrap', FormStore)
        }
        next()
      }
    },
    /**
     * System Configuration
     */
    {
      path: 'system_configuration',
      component: SystemConfigurationSection
    },
    ...MaintenanceTasksRoutes,
    ...SslCertificatesRoutes,
    {
      path: 'general',
      name: 'general',
      component: MainTabs,
      props: (route) => ({ tab: 'general', query: route.query.query })
    },
    {
      path: 'alerting',
      name: 'alerting',
      component: MainTabs,
      props: (route) => ({ tab: 'alerting', query: route.query.query })
    },
    ...AdvancedRoutes,
    {
      path: 'services',
      name: 'services',
      component: MainTabs,
      props: (route) => ({ tab: 'services', query: route.query.query })
    },
    {
      path: 'database',
      name: 'database',
      component: DatabaseTabs,
      props: (route) => ({ tab: 'database', query: route.query.query })
    },
    {
      path: 'database_advanced',
      name: 'database_advanced',
      component: DatabaseTabs,
      props: (route) => ({ tab: 'database_advanced', query: route.query.query })
    },
    ...ActiveActiveRoutes,
    {
      path: 'radius',
      name: 'radiusGeneral',
      component: RadiusTabs,
      props: (route) => ({ tab: 'radiusGeneral', query: route.query.query })
    },
    {
      path: 'radius/eap',
      name: 'radiusEaps',
      component: RadiusTabs,
      props: (route) => ({ tab: 'radiusEaps', query: route.query.query })
    },
    {
      path: 'radius/eap_new',
      name: 'newRadiusEap',
      component: RadiusEapView,
      props: () => ({ formStoreName: 'formRadiusEap', isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusEap) { // Register store module only once
          store.registerModule('formRadiusEap', FormStore)
        }
        next()
      }
    },
    {
      path: 'radius/eap/:id',
      name: 'radiusEap',
      component: RadiusEapView,
      props: (route) => ({ formStoreName: 'formRadiusEap', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusEap) { // Register store module only once
          store.registerModule('formRadiusEap', FormStore)
        }
        store.dispatch('$_radius_eap/getRadiusEap', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'radius/eap/:id/clone',
      name: 'cloneRadiusEap',
      component: RadiusEapView,
      props: (route) => ({ formStoreName: 'formRadiusEap', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusEap) { // Register store module only once
          store.registerModule('formRadiusEap', FormStore)
        }
        store.dispatch('$_radius_eap/getRadiusEap', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'radius/tls',
      name: 'radiusTlss',
      component: RadiusTabs,
      props: (route) => ({ tab: 'radiusTlss', query: route.query.query })
    },
    {
      path: 'radius/tls_new',
      name: 'newRadiusTls',
      component: RadiusTlsView,
      props: () => ({ formStoreName: 'formRadiusTls', isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusTls) { // Register store module only once
          store.registerModule('formRadiusTls', FormStore)
        }
        next()
      }
    },
    {
      path: 'radius/tls/:id',
      name: 'radiusTls',
      component: RadiusTlsView,
      props: (route) => ({ formStoreName: 'formRadiusTls', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusTls) { // Register store module only once
          store.registerModule('formRadiusTls', FormStore)
        }
        store.dispatch('$_radius_tls/getRadiusTls', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'radius/tls/:id/clone',
      name: 'cloneRadiusTls',
      component: RadiusTlsView,
      props: (route) => ({ formStoreName: 'formRadiusTls', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusTls) { // Register store module only once
          store.registerModule('formRadiusTls', FormStore)
        }
        store.dispatch('$_radius_tls/getRadiusTls', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'radius/fast',
      name: 'radiusFasts',
      component: RadiusTabs,
      props: (route) => ({ tab: 'radiusFasts', query: route.query.query })
    },
    {
      path: 'radius/fast_new',
      name: 'newRadiusFast',
      component: RadiusFastView,
      props: () => ({ formStoreName: 'formRadiusFast', isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusFast) { // Register store module only once
          store.registerModule('formRadiusFast', FormStore)
        }
        next()
      }
    },
    {
      path: 'radius/fast/:id',
      name: 'radiusFast',
      component: RadiusFastView,
      props: (route) => ({ formStoreName: 'formRadiusFast', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusFast) { // Register store module only once
          store.registerModule('formRadiusFast', FormStore)
        }
        store.dispatch('$_radius_fast/getRadiusFast', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'radius/fast/:id/clone',
      name: 'cloneRadiusFast',
      component: RadiusFastView,
      props: (route) => ({ formStoreName: 'formRadiusFast', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusFast) { // Register store module only once
          store.registerModule('formRadiusFast', FormStore)
        }
        store.dispatch('$_radius_fast/getRadiusFast', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'radius/ssl',
      name: 'radiusSsls',
      component: RadiusTabs,
      props: (route) => ({ tab: 'radiusSsls', query: route.query.query })
    },
    {
      path: 'radius/ssl_new',
      name: 'newRadiusSsl',
      component: RadiusSslView,
      props: () => ({ formStoreName: 'formRadiusSsl', isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusSsl) { // Register store module only once
          store.registerModule('formRadiusSsl', FormStore)
        }
        next()
      }
    },
    {
      path: 'radius/ssl/:id',
      name: 'radiusSsl',
      component: RadiusSslView,
      props: (route) => ({ formStoreName: 'formRadiusSsl', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusSsl) { // Register store module only once
          store.registerModule('formRadiusSsl', FormStore)
        }
        store.dispatch('$_radius_ssl/getRadiusSsl', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'radius/ssl/:id/clone',
      name: 'cloneRadiusSsl',
      component: RadiusSslView,
      props: (route) => ({ formStoreName: 'formRadiusSsl', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusSsl) { // Register store module only once
          store.registerModule('formRadiusSsl', FormStore)
        }
        store.dispatch('$_radius_ssl/getRadiusSsl', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'radius/ocsp',
      name: 'radiusOcsps',
      component: RadiusTabs,
      props: (route) => ({ tab: 'radiusOcsps', query: route.query.query })
    },
    {
      path: 'radius/ocsp_new',
      name: 'newRadiusOcsp',
      component: RadiusOcspView,
      props: () => ({ formStoreName: 'formRadiusOcsp', isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusOcsp) { // Register store module only once
          store.registerModule('formRadiusOcsp', FormStore)
        }
        next()
      }
    },
    {
      path: 'radius/ocsp/:id',
      name: 'radiusOcsp',
      component: RadiusOcspView,
      props: (route) => ({ formStoreName: 'formRadiusOcsp', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusOcsp) { // Register store module only once
          store.registerModule('formRadiusOcsp', FormStore)
        }
        store.dispatch('$_radius_ocsp/getRadiusOcsp', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'radius/ocsp/:id/clone',
      name: 'cloneRadiusOcsp',
      component: RadiusOcspView,
      props: (route) => ({ formStoreName: 'formRadiusOcsp', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formRadiusOcsp) { // Register store module only once
          store.registerModule('formRadiusOcsp', FormStore)
        }
        store.dispatch('$_radius_ocsp/getRadiusOcsp', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'dns',
      name: 'dns',
      component: DnsView,
      props: (route) => ({ formStoreName: 'formDns', query: route.query.query }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formDns) { // Register store module only once
          store.registerModule('formDns', FormStore)
        }
        next()
      }
    },
    {
      path: 'admin_roles',
      name: 'admin_roles',
      component: AdminRolesList,
      props: (route) => ({ query: route.query.query })
    },
    {
      path: 'admin_roles/new',
      name: 'newAdminRole',
      component: AdminRoleView,
      props: () => ({ formStoreName: 'formAdminRole', isNew: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formAdminRole) { // Register store module only once
          store.registerModule('formAdminRole', FormStore)
        }
        next()
      }
    },
    {
      path: 'admin_role/:id',
      name: 'admin_role',
      component: AdminRoleView,
      props: (route) => ({ formStoreName: 'formAdminRole', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formAdminRole) { // Register store module only once
          store.registerModule('formAdminRole', FormStore)
        }
        store.dispatch('$_admin_roles/getAdminRole', to.params.id).then(() => {
          next()
        })
      }
    },
    {
      path: 'admin_role/:id/clone',
      name: 'cloneAdminRole',
      component: AdminRoleView,
      props: (route) => ({ formStoreName: 'formAdminRole', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        if (!store.state.formAdminRole) { // Register store module only once
          store.registerModule('formAdminRole', FormStore)
        }
        store.dispatch('$_admin_roles/getAdminRole', to.params.id).then(() => {
          next()
        })
      }
    }
  ]
}

export default route
