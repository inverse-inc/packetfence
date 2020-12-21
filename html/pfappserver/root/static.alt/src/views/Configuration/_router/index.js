import acl from '@/utils/acl'
import store from '@/store'
import FormStore from '@/store/base/form'
import ConfigurationView from '../'
import AdminRolesStore from '../_store/adminRoles'
import BasesStore from '../_store/bases'
import ConnectionProfilesStore from '../_store/connectionProfiles'
import PortalModulesStore from '../_store/portalModules'

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
import SyslogForwardersRoutes from '../syslogForwarders/_router'
import WrixRoutes from '../wrix/_router'
import PkiRoutes from '../pki/_router'

/* Advanced Access Configuration */
const AdvancedAccessConfigurationSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/AdvancedAccessConfigurationSection')
import CaptivePortalRoutes from '../captivePortal/_router'
import FilterEnginesRoutes from '../filterEngines/_router'
import BillingTiersRoutes from '../billingTiers/_router'
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
import FloatingDevicesRoutes from '../floatingDevices/_router'
import SslCertificatesRoutes from '../sslCertificates/_router'

/* System Configuration */
const SystemConfigurationSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/SystemConfigurationSection')
export const MainTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/MainTabs')
import GeneralRoutes from '../general/_router'
import AlertingRoutes from '../alerting/_router'
import AdvancedRoutes from '../advanced/_router'
import MaintenanceTasksRoutes from '../maintenanceTasks/_router'
import ServicesRoutes from '../services/_router'
const DatabaseTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/DatabaseTabs')
import ActiveActiveRoutes from '../activeActive/_router'
import RadiusRoutes from '../radius/_router'
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
    if (!store.state.$_connection_profiles) {
      store.registerModule('$_connection_profiles', ConnectionProfilesStore)
    }
    if (!store.state.$_portalmodules) {
      store.registerModule('$_portalmodules', PortalModulesStore)
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
    ...SyslogForwardersRoutes,
    ...WrixRoutes,
    ...PkiRoutes,
    /**
     *  Advanced Access Configuration
     */
    {
      path: 'advanced_access_configuration',
      component: AdvancedAccessConfigurationSection
    },
    ...FilterEnginesRoutes,
    ...CaptivePortalRoutes,
    ...BillingTiersRoutes,
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
    ...FloatingDevicesRoutes,
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
    ...GeneralRoutes,
    ...AlertingRoutes,
    ...AdvancedRoutes,
    ...MaintenanceTasksRoutes,
    ...ServicesRoutes,
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
    ...RadiusRoutes,
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
    },
    ...SslCertificatesRoutes
  ]
}

export default route
