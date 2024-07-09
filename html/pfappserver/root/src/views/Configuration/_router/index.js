import acl from '@/utils/acl'
import ConfigurationView from '../'

/* Policies Access Control */
const PoliciesAccessControlSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/TheSectionPoliciesAccessControl')
import RolesRoutes from '../roles/_router'
import DomainsRoutes from '../domains/_router'
import RealmsRoutes from '../realms/_router'
import SourcesRoutes from '../sources/_router'
import SwitchesRoutes from '../switches/_router'
import SwitchGroupsRoutes from '../switchGroups/_router'
import ConnectionProfilesRoutes from '../connectionProfiles/_router'

/* Compliance */
const ComplianceSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/TheSectionCompliance')
import FingerbankRoutes from '../fingerbank/_router'
import NetworkBehaviorPoliciesRoutes from '../networkBehaviorPolicy/_router'
import ScanEnginesRoutes from '../scanEngines/_router'
import SecurityEventsRoutes from '../securityEvents/_router'

/* Integration */
const IntegrationSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/TheSectionIntegration')
import CloudsRoutes from '../clouds/_router'
import FirewallsRoutes from '../firewalls/_router'
import WebServicesRoutes from '../webServices/_router'
import SwitchTemplatesRoutes from '../switchTemplates/_router'
import EventHandlersRoutes from '../eventHandlers/_router'
import SyslogForwardersRoutes from '../syslogForwarders/_router'
import WrixRoutes from '../wrix/_router'
import PkiRoutes from '../pki/_router'
import MfasRoutes from '../mfas/_router'

/* Advanced Access Configuration */
const AdvancedAccessConfigurationSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/TheSectionAdvancedAccessConfiguration')
import CaptivePortalRoutes from '../captivePortal/_router'
import FilterEnginesRoutes from '../filterEngines/_router'
import BillingTiersRoutes from '../billingTiers/_router'
import PkiProvidersRoutes from '../pkiProviders/_router'
import PortalModulesRoutes from '../portalModules/_router'
import AccessDurationsRoutes from '../accessDurations/_router'
import ProvisionersRoutes from '../provisioners/_router'
import SelfServicesRoutes from '../selfServices/_router'
import EventLoggersRoutes from '../eventLoggers/_router'

/* Network Configuration */
const NetworkConfigurationSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/TheSectionNetworkConfiguration')
import NetworksRoutes from '../networks/_router'
import SnmpTrapsRoutes from '../snmpTraps/_router'
import FloatingDevicesRoutes from '../floatingDevices/_router'
import SslCertificatesRoutes from '../sslCertificates/_router'

/* System Configuration */
const SystemConfigurationSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/TheSectionSystemConfiguration')
import GeneralRoutes from '../general/_router'
import AlertingRoutes from '../alerting/_router'
import AdvancedRoutes from '../advanced/_router'
import MaintenanceTasksRoutes from '../maintenanceTasks/_router'
import MonitRoutes from '../monit/_router'
import ServicesRoutes from '../services/_router'
import DatabaseRoutes from '../database/_router'
import ActiveActiveRoutes from '../activeActive/_router'
import FleetDMRoutes from '../fleetDM/_router'
import RadiusRoutes from '../radius/_router'
import DnsRoutes from '../dns/_router'
import AdminLoginRoutes from '../adminLogin/_router'
import AdminRolesRoutes from '../adminRoles/_router'
import ConnectorsRoutes from '../connectors/_router'

import store from '@/store'
import BasesStoreModule from '../bases/_store'
export const beforeEnter = (to, from, next = () => { }) => {
  if (!store.state.$_bases) {
    store.registerModule('$_bases', BasesStoreModule)
  }
  next()
}

const can = () => !store.getters['system/isSaas']

const route = {
  path: '/configuration',
  name: 'configuration',
  redirect: '/configuration/policies_access_control',
  component: ConfigurationView,
  beforeEnter,
  meta: {
    can: () => acl.$can('read', 'configuration_main'), // has ACL for 1+ children
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
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
    ...ConnectionProfilesRoutes,

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

    /**
     * Integration
     */
    {
      path: 'integration',
      component: IntegrationSection
    },
    ...CloudsRoutes,
    ...FirewallsRoutes,
    ...WebServicesRoutes,
    ...SwitchTemplatesRoutes,
    ...EventHandlersRoutes,
    ...SyslogForwardersRoutes,
    ...WrixRoutes,
    ...PkiRoutes,
    ...MfasRoutes,

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
    ...PortalModulesRoutes,
    ...AccessDurationsRoutes,
    ...SelfServicesRoutes,
    ...EventLoggersRoutes,

    /**
     * Network Configuration
     */
    {
      path: 'network_configuration',
      component: NetworkConfigurationSection,
      meta: {
        can
      }
    },
    ...NetworksRoutes,
    ...FloatingDevicesRoutes,
    ...SnmpTrapsRoutes,

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
    ...MonitRoutes,
    ...ServicesRoutes,
    ...DatabaseRoutes,
    ...ActiveActiveRoutes,
    ...FleetDMRoutes,
    ...RadiusRoutes,
    ...DnsRoutes,
    ...AdminLoginRoutes,
    ...AdminRolesRoutes,
    ...SslCertificatesRoutes,
    ...ConnectorsRoutes
  ]
}

export default route
