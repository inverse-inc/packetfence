import store from '@/store'
import ConfigurationView from '../'
import AdminRolesStore from '../_store/adminRoles'
import AuthenticationSourcesStore from '../_store/sources'
import BasesStore from '../_store/bases'
import BillingTiersStore from '../_store/billingTiers'
import CertificatesStore from '../_store/certificates'
import ConnectionProfilesStore from '../_store/connectionProfiles'
import DeviceRegistrationsStore from '../_store/deviceRegistrations'
import DomainsStore from '../_store/domains'
import FiltersStore from '../_store/filters'
import FingerbankStore from '../_store/fingerbank'
import FirewallsStore from '../_store/firewalls'
import FloatingDevicesStore from '../_store/floatingDevices'
import InterfacesStore from '../_store/interfaces'
import MaintenanceTasksStore from '../_store/maintenanceTasks'
import PkiProvidersStore from '../_store/pkiProviders'
import PortalModulesStore from '../_store/portalModules'
import ProvisioningsStore from '../_store/provisionings'
import RealmsStore from '../_store/realms'
import RolesStore from '../_store/roles'
import RoutedNetworksStore from '../_store/routedNetworks'
import ScansStore from '../_store/scans'
// import SecurityEventsStore from '../_store/securityEvents'
import ServicesStore from '../_store/services'
import SyslogForwardersStore from '../_store/syslogForwarders'
import SyslogParsersStore from '../_store/syslogParsers'
import SwitchesStore from '../_store/switches'
import SwitchGroupsStore from '../_store/switchGroups'
import TrafficShapingPoliciesStore from '../_store/trafficShapingPolicies'
import WmiRulesStore from '../_store/wmiRules'
import WrixLocationsStore from '../_store/wrixLocations'

/* Policies Access Control */
const PoliciesAccessControlSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/PoliciesAccessControlSection')
const RolesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/RolesList')
const RoleView = () => import(/* webpackChunkName: "Configuration" */ '../_components/RoleView')
const DomainsTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/DomainsTabs')
const DomainView = () => import(/* webpackChunkName: "Configuration" */ '../_components/DomainView')
const RealmView = () => import(/* webpackChunkName: "Configuration" */ '../_components/RealmView')
const AuthenticationSourcesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/AuthenticationSourcesList')
const AuthenticationSourceView = () => import(/* webpackChunkName: "Configuration" */ '../_components/AuthenticationSourceView')
const NetworkDevicesTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/NetworkDevicesTabs')
const SwitchView = () => import(/* webpackChunkName: "Configuration" */ '../_components/SwitchView')
const SwitchGroupView = () => import(/* webpackChunkName: "Configuration" */ '../_components/SwitchGroupView')
const ConnectionProfilesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/ConnectionProfilesList')
const ConnectionProfileView = () => import(/* webpackChunkName: "Configuration" */ '../_components/ConnectionProfileView')
const ConnectionProfileFileView = () => import(/* webpackChunkName: "Configuration" */ '../_components/ConnectionProfileFileView')

/* Compliance */
const ComplianceSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/ComplianceSection')
const FingerbankTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/FingerbankTabs')
const FingerbankCombinationView = () => import(/* webpackChunkName: "Configuration" */ '../_components/FingerbankCombinationView')
const FingerbankDhcpFingerprintView = () => import(/* webpackChunkName: "Configuration" */ '../_components/FingerbankDhcpFingerprintView')
const ScansTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/ScansTabs')
const ScanEngineView = () => import(/* webpackChunkName: "Configuration" */ '../_components/ScanEngineView')
const WmiRuleView = () => import(/* webpackChunkName: "Configuration" */ '../_components/WmiRuleView')
// const SecurityEventsList = () => import(/* webpackChunkName: "Configuration" */ '../_components/SecurityEventsList')
// const SecurityEventView = () => import(/* webpackChunkName: "Configuration" */ '../_components/SecurityEventView')

/* Integration */
const IntegrationSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/IntegrationSection')
const FirewallsList = () => import(/* webpackChunkName: "Configuration" */ '../_components/FirewallsList')
const FirewallView = () => import(/* webpackChunkName: "Configuration" */ '../_components/FirewallView')
const CiscoMobilityServicesEngineView = () => import(/* webpackChunkName: "Configuration" */ '../_components/CiscoMobilityServicesEngineView')
const WebServicesView = () => import(/* webpackChunkName: "Configuration" */ '../_components/WebServicesView')
const SyslogParsersList = () => import(/* webpackChunkName: "Configuration" */ '../_components/SyslogParsersList')
const SyslogParserView = () => import(/* webpackChunkName: "Configuration" */ '../_components/SyslogParserView')
const SyslogForwardersList = () => import(/* webpackChunkName: "Configuration" */ '../_components/SyslogForwardersList')
const SyslogForwarderView = () => import(/* webpackChunkName: "Configuration" */ '../_components/SyslogForwarderView')
const WrixLocationsList = () => import(/* webpackChunkName: "Configuration" */ '../_components/WrixLocationsList')
const WrixLocationView = () => import(/* webpackChunkName: "Configuration" */ '../_components/WrixLocationView')

/* Advanced Access Configuration */
const CaptivePortalView = () => import(/* webpackChunkName: "Configuration" */ '../_components/CaptivePortalView')
const FilterEngineTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/FilterEngineTabs')
const BillingTiersList = () => import(/* webpackChunkName: "Configuration" */ '../_components/BillingTiersList')
const BillingTierView = () => import(/* webpackChunkName: "Configuration" */ '../_components/BillingTierView')
const PkiProvidersList = () => import(/* webpackChunkName: "Configuration" */ '../_components/PkiProvidersList')
const PkiProviderView = () => import(/* webpackChunkName: "Configuration" */ '../_components/PkiProviderView')
const PortalModulesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/PortalModulesList')
const PortalModuleView = () => import(/* webpackChunkName: "Configuration" */ '../_components/PortalModuleView')
const AccessDurationView = () => import(/* webpackChunkName: "Configuration" */ '../_components/AccessDurationView')
const ProvisioningsList = () => import(/* webpackChunkName: "Configuration" */ '../_components/ProvisioningsList')
const ProvisioningView = () => import(/* webpackChunkName: "Configuration" */ '../_components/ProvisioningView')
const DeviceRegistrationsList = () => import(/* webpackChunkName: "Configuration" */ '../_components/DeviceRegistrationsList')
const DeviceRegistrationView = () => import(/* webpackChunkName: "Configuration" */ '../_components/DeviceRegistrationView')

/* Network Configuration */
const NetworkConfigurationSection = () => import(/* webpackChunkName: "Configuration" */ '../_components/NetworkConfigurationSection')
const NetworksTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/NetworksTabs')
const InterfaceView = () => import(/* webpackChunkName: "Configuration" */ '../_components/InterfaceView')
const RoutedNetworkView = () => import(/* webpackChunkName: "Configuration" */ '../_components/RoutedNetworkView')
const TrafficShapingView = () => import(/* webpackChunkName: "Configuration" */ '../_components/TrafficShapingView')
const SnmpTrapView = () => import(/* webpackChunkName: "Configuration" */ '../_components/SnmpTrapView')
const FloatingDevicesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/FloatingDevicesList')
const FloatingDeviceView = () => import(/* webpackChunkName: "Configuration" */ '../_components/FloatingDeviceView')
const CertificatesView = () => import(/* webpackChunkName: "Configuration" */ '../_components/CertificatesView')

/* Main Configuration */
const MainTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/MainTabs')
const MaintenanceTaskView = () => import(/* webpackChunkName: "Configuration" */ '../_components/MaintenanceTaskView')
const DatabaseTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/DatabaseTabs')
const ActiveActiveView = () => import(/* webpackChunkName: "Configuration" */ '../_components/ActiveActiveView')
const RadiusView = () => import(/* webpackChunkName: "Configuration" */ '../_components/RadiusView')
const AdminRolesList = () => import(/* webpackChunkName: "Configuration" */ '../_components/AdminRolesList')
const AdminRoleView = () => import(/* webpackChunkName: "Configuration" */ '../_components/AdminRoleView')

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
    if (!store.state.$_admin_roles) {
      store.registerModule('$_admin_roles', AdminRolesStore)
    }
    if (!store.state.$_bases) {
      store.registerModule('$_bases', BasesStore)
      // preload config/bases (all sections)
      store.dispatch('$_bases/all')
    }
    if (!store.state.$_billing_tiers) {
      store.registerModule('$_billing_tiers', BillingTiersStore)
    }
    if (!store.state.$_domains) {
      store.registerModule('$_domains', DomainsStore)
    }
    if (!store.state.$_certificates) {
      store.registerModule('$_certificates', CertificatesStore)
    }
    if (!store.state.$_connection_profiles) {
      store.registerModule('$_connection_profiles', ConnectionProfilesStore)
    }
    if (!store.state.$_device_registrations) {
      store.registerModule('$_device_registrations', DeviceRegistrationsStore)
    }
    if (!store.state.$_filters) {
      store.registerModule('$_filters', FiltersStore)
    }
    if (!store.state.$_fingerbank) {
      store.registerModule('$_fingerbank', FingerbankStore)
    }
    if (!store.state.$_firewalls) {
      store.registerModule('$_firewalls', FirewallsStore)
    }
    if (!store.state.$_floatingdevices) {
      store.registerModule('$_floatingdevices', FloatingDevicesStore)
    }
    if (!store.state.$_interfaces) {
      store.registerModule('$_interfaces', InterfacesStore)
    }
    if (!store.state.$_maintenance_tasks) {
      store.registerModule('$_maintenance_tasks', MaintenanceTasksStore)
    }
    if (!store.state.$_pki_providers) {
      store.registerModule('$_pki_providers', PkiProvidersStore)
    }
    if (!store.state.$_portalmodules) {
      store.registerModule('$_portalmodules', PortalModulesStore)
    }
    if (!store.state.$_provisionings) {
      store.registerModule('$_provisionings', ProvisioningsStore)
    }
    if (!store.state.$_realms) {
      store.registerModule('$_realms', RealmsStore)
    }
    if (!store.state.$_roles) {
      store.registerModule('$_roles', RolesStore)
    }
    if (!store.state.$_routed_networks) {
      store.registerModule('$_routed_networks', RoutedNetworksStore)
    }
    if (!store.state.$_scans) {
      store.registerModule('$_scans', ScansStore)
    }
    // if (!store.state.$_security_events) {
    //   store.registerModule('$_security_events', SecurityEventsStore)
    // }
    if (!store.state.$_services) {
      store.registerModule('$_services', ServicesStore)
    }
    if (!store.state.$_sources) {
      store.registerModule('$_sources', AuthenticationSourcesStore)
    }
    if (!store.state.$_syslog_parsers) {
      store.registerModule('$_syslog_parsers', SyslogParsersStore)
    }
    if (!store.state.$_syslog_forwarders) {
      store.registerModule('$_syslog_forwarders', SyslogForwardersStore)
    }
    if (!store.state.$_switches) {
      store.registerModule('$_switches', SwitchesStore)
    }
    if (!store.state.$_switch_groups) {
      store.registerModule('$_switch_groups', SwitchGroupsStore)
    }
    if (!store.state.$_traffic_shaping_policies) {
      store.registerModule('$_traffic_shaping_policies', TrafficShapingPoliciesStore)
    }
    if (!store.state.$_wmi_rules) {
      store.registerModule('$_wmi_rules', WmiRulesStore)
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
      path: 'policesaccesscontrol',
      component: PoliciesAccessControlSection
    },
    {
      path: 'roles',
      name: 'roles',
      component: RolesList,
      props: (route) => ({ storeName: '$_roles', query: route.query.query })
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
      path: 'role/:id/clone',
      name: 'cloneRole',
      component: RoleView,
      props: (route) => ({ storeName: '$_roles', id: route.params.id, isClone: true }),
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
      props: (route) => ({ tab: 'domains', storeName: '$_domains', iquery: route.query.query })
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
      path: 'domain/:id/clone',
      name: 'cloneDomain',
      component: DomainView,
      props: (route) => ({ storeName: '$_domains', id: route.params.id, isClone: true }),
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
      props: (route) => ({ tab: 'realms', storeName: '$_realms', query: route.query.query })
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
      path: 'realm/:id/clone',
      name: 'cloneRealm',
      component: RealmView,
      props: (route) => ({ storeName: '$_realms', id: route.params.id, isClone: true }),
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
      props: (route) => ({ storeName: '$_sources', query: route.query.query })
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
      props: (route) => ({ tab: 'switches', storeName: '$_switches', query: route.query.query })
    },
    {
      path: 'switches/new/:switchGroup',
      name: 'newSwitch',
      component: SwitchView,
      props: (route) => ({ storeName: '$_switches', isNew: true, switchGroup: route.params.switchGroup })
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
      path: 'switch/:id/clone',
      name: 'cloneSwitch',
      component: SwitchView,
      props: (route) => ({ storeName: '$_switches', id: route.params.id, isClone: true }),
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
      props: (route) => ({ tab: 'switch_groups', storeName: '$_switch_groups', query: route.query.query })
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
    {
      path: 'switch_group/:id/clone',
      name: 'cloneSwitchGroup',
      component: SwitchGroupView,
      props: (route) => ({ storeName: '$_switch_groups', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_switch_groups/getSwitchGroup', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'connection_profiles',
      name: 'connection_profiles',
      component: ConnectionProfilesList,
      props: (route) => ({ storeName: '$_connection_profiles', tab: 'connection_profiles', query: route.query.query })
    },
    {
      path: 'connection_profiles/new',
      name: 'newConnectionProfile',
      component: ConnectionProfileView,
      props: (route) => ({ storeName: '$_connection_profiles', isNew: true })
    },
    {
      path: 'connection_profile/:id',
      name: 'connection_profile',
      component: ConnectionProfileView,
      props: (route) => ({ storeName: '$_connection_profiles', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_connection_profiles/getConnectionProfile', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'connection_profile/:id/clone',
      name: 'cloneConnectionProfile',
      component: ConnectionProfileView,
      props: (route) => ({ storeName: '$_connection_profiles', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_connection_profiles/getConnectionProfile', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'connection_profile/:id/files',
      name: 'connectionProfileFiles',
      component: ConnectionProfileView,
      props: (route) => ({ storeName: '$_connection_profiles', id: route.params.id, tabIndex: 2 }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_connection_profiles/getConnectionProfile', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'connection_profile/:id/files/:path/new',
      name: 'newConnectionProfileFile',
      component: ConnectionProfileFileView,
      props: (route) => ({ storeName: '$_connection_profiles', id: route.params.id, filename: route.params.path, isNew: true })
    },
    {
      path: 'connection_profile/:id/files/:filename',
      name: 'connectionProfileFile',
      component: ConnectionProfileFileView,
      props: (route) => ({ storeName: '$_connection_profiles', id: route.params.id, filename: route.params.filename })
    },
    /**
     * Compliance
     */
    {
      path: 'compliance',
      component: ComplianceSection
    },
    {
      path: 'fingerbank',
      redirect: 'fingerbank/general_settings'
    },
    {
      path: 'fingerbank/general_settings',
      name: 'fingerbankGeneralSettings',
      component: FingerbankTabs,
      props: (route) => ({ tab: 'general_settings', storeName: '$_fingerbank', query: route.query.query })
    },
    {
      path: 'fingerbank/device_change_detection',
      name: 'fingerbankDeviceChangeDetection',
      component: FingerbankTabs,
      props: (route) => ({ tab: 'device_change_detection', storeName: '$_fingerbank', query: route.query.query })
    },
    {
      path: 'fingerbank/combinations',
      name: 'fingerbankCombinations',
      component: FingerbankTabs,
      props: (route) => ({ tab: 'combinations', storeName: '$_fingerbank', query: route.query.query })
    },
    {
      path: 'fingerbank/combinations/new',
      name: 'newFingerbankCombination',
      component: FingerbankCombinationView,
      props: (route) => ({ storeName: '$_fingerbank', isNew: true })
    },
    {
      path: 'fingerbank/combination/:id',
      name: 'fingerbankCombination',
      component: FingerbankCombinationView,
      props: (route) => ({ storeName: '$_fingerbank', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_fingerbank/getCombination', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'fingerbank/combination/:id/clone',
      name: 'cloneFingerbankCombination',
      component: FingerbankCombinationView,
      props: (route) => ({ storeName: '$_fingerbank', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_fingerbank/getCombination', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'fingerbank/devices',
      name: 'fingerbankDevices',
      component: FingerbankTabs,
      props: (route) => ({ tab: 'devices', storeName: '$_fingerbank', query: route.query.query })
    },
    {
      path: 'fingerbank/devices/:parentId',
      name: 'fingerbankDevicesByParentId',
      component: FingerbankTabs,
      props: (route) => ({ tab: 'devices', storeName: '$_fingerbank', query: route.query.query, parentId: route.params.parentId })
    },
    {
      path: 'fingerbank/dhcp_fingerprints',
      name: 'fingerbankDhcpFingerprints',
      component: FingerbankTabs,
      props: (route) => ({ tab: 'dhcp_fingerprints', storeName: '$_fingerbank', query: route.query.query })
    },
    {
      path: 'fingerbank/dhcp_fingerprints/:id',
      name: 'fingerbankDhcpFingerprint',
      component: FingerbankDhcpFingerprintView,
      props: (route) => ({ storeName: '$_fingerbank', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_fingerbank/getDhcpFingerprint', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'fingerbank/dhcp_vendors',
      name: 'fingerbankDhcpVendors',
      component: FingerbankTabs,
      props: (route) => ({ tab: 'dhcp_vendors', storeName: '$_fingerbank', query: route.query.query })
    },
    {
      path: 'fingerbank/dhcpv6_fingerprints',
      name: 'fingerbankDhcpv6Fingerprints',
      component: FingerbankTabs,
      props: (route) => ({ tab: 'dhcpv6_fingerprints', storeName: '$_fingerbank', query: route.query.query })
    },
    {
      path: 'fingerbank/dhcpv6_enterprises',
      name: 'fingerbankDhcpv6Enterprises',
      component: FingerbankTabs,
      props: (route) => ({ tab: 'dhcpv6_enterprises', storeName: '$_fingerbank', query: route.query.query })
    },
    {
      path: 'fingerbank/mac_vendors',
      name: 'fingerbankMacVendors',
      component: FingerbankTabs,
      props: (route) => ({ tab: 'mac_vendors', storeName: '$_fingerbank', query: route.query.query })
    },
    {
      path: 'fingerbank/user_agents',
      name: 'fingerbankUserAgents',
      component: FingerbankTabs,
      props: (route) => ({ tab: 'user_agents', storeName: '$_fingerbank', query: route.query.query })
    },





    {
      path: 'scans',
      redirect: 'scans/scan_engines'
    },
    {
      path: 'scans/scan_engines',
      name: 'scanEngines',
      component: ScansTabs,
      props: (route) => ({ tab: 'scan_engines', storeName: '$_scans', query: route.query.query })
    },
    {
      path: 'scans/scan_engines/new/:scanType',
      name: 'newScanEngine',
      component: ScanEngineView,
      props: (route) => ({ storeName: '$_scans', isNew: true, scanType: route.params.scanType })
    },
    {
      path: 'scans/scan_engine/:id',
      name: 'scanEngine',
      component: ScanEngineView,
      props: (route) => ({ storeName: '$_scans', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_scans/getScanEngine', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'scans/scan_engine/:id/clone',
      name: 'cloneScanEngine',
      component: ScanEngineView,
      props: (route) => ({ storeName: '$_scans', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_scans/getScanEngine', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'scans/wmi_rules',
      name: 'wmiRules',
      component: ScansTabs,
      props: (route) => ({ storeName: '$_scans', tab: 'wmi_rules', query: route.query.query })
    },
    {
      path: 'scans/wmi_rules/new',
      name: 'newWmiRule',
      component: WmiRuleView,
      props: (route) => ({ storeName: '$_wmi_rules', isNew: true })
    },
    {
      path: 'scans/wmi_rule/:id',
      name: 'wmiRule',
      component: WmiRuleView,
      props: (route) => ({ storeName: '$_wmi_rules', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_wmi_rules/getWmiRule', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'scans/wmi_rule/:id/clone',
      name: 'cloneWmiRule',
      component: WmiRuleView,
      props: (route) => ({ storeName: '$_wmi_rules', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_wmi_rules/getWmiRule', to.params.id).then(object => {
          next()
        })
      }
    },
    /*
    {
      path: 'security_events',
      name: 'security_events',
      component: SecurityEventsList,
      props: (route) => ({ storeName: '$_security_events', query: route.query.query })
    },
    {
      path: 'security_events/new',
      name: 'newSecurityEvent',
      component: SecurityEventView,
      props: (route) => ({ storeName: '$_security_events', isNew: true })
    },
    {
      path: 'security_event/:id',
      name: 'security_event',
      component: SecurityEventView,
      props: (route) => ({ storeName: '$_security_events', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_security_events/getSecurityEvent', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'security_event/:id/clone',
      name: 'cloneSecurityEvent',
      component: SecurityEventView,
      props: (route) => ({ storeName: '$_security_events', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_security_events/getSecurityEvent', to.params.id).then(object => {
          next()
        })
      }
    },
    */
    /**
     * Integration
     */
    {
      path: 'integration',
      component: IntegrationSection
    },
    {
      path: 'firewalls',
      name: 'firewalls',
      component: FirewallsList,
      props: (route) => ({ storeName: '$_firewalls', query: route.query.query })
    },
    {
      path: 'firewalls/new/:firewallType',
      name: 'newFirewall',
      component: FirewallView,
      props: (route) => ({ storeName: '$_firewalls', isNew: true, firewallType: route.params.firewallType })
    },
    {
      path: 'firewall/:id',
      name: 'firewall',
      component: FirewallView,
      props: (route) => ({ storeName: '$_firewalls', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_firewalls/getFirewall', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'firewall/:id/clone',
      name: 'cloneFirewall',
      component: FirewallView,
      props: (route) => ({ storeName: '$_firewalls', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_firewalls/getFirewall', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'mse',
      name: 'mse',
      component: CiscoMobilityServicesEngineView,
      props: (route) => ({ storeName: '$_bases', query: route.query.query })
    },
    {
      path: 'webservices',
      name: 'webservices',
      component: WebServicesView,
      props: (route) => ({ storeName: '$_bases', query: route.query.query })
    },
    {
      path: 'pfdetect',
      name: 'syslogParsers',
      component: SyslogParsersList,
      props: (route) => ({ storeName: '$_syslog_parsers', query: route.query.query })
    },
    {
      path: 'pfdetect/new/:syslogParserType',
      name: 'newSyslogParser',
      component: SyslogParserView,
      props: (route) => ({ storeName: '$_syslog_parsers', isNew: true, syslogParserType: route.params.syslogParserType })
    },
    {
      path: 'pfdetect/:id',
      name: 'syslogParser',
      component: SyslogParserView,
      props: (route) => ({ storeName: '$_syslog_parsers', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_syslog_parsers/getSyslogParser', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'pfdetect/:id/clone',
      name: 'cloneSyslogParser',
      component: SyslogParserView,
      props: (route) => ({ storeName: '$_syslog_parsers', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_syslog_parsers/getSyslogParser', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'syslog',
      name: 'syslogForwarders',
      component: SyslogForwardersList,
      props: (route) => ({ storeName: '$_syslog_forwarders', query: route.query.query })
    },
    {
      path: 'syslog/new/:syslogForwarderType',
      name: 'newSyslogForwarder',
      component: SyslogForwarderView,
      props: (route) => ({ storeName: '$_syslog_forwarders', isNew: true, syslogForwarderType: route.params.syslogForwarderType })
    },
    {
      path: 'syslog/:id',
      name: 'syslogForwarder',
      component: SyslogForwarderView,
      props: (route) => ({ storeName: '$_syslog_forwarders', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_syslog_forwarders/getSyslogForwarder', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'syslog/:id/clone',
      name: 'cloneSyslogForwarder',
      component: SyslogForwarderView,
      props: (route) => ({ storeName: '$_syslog_forwarders', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_syslog_forwarders/getSyslogForwarder', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'wrix',
      name: 'wrixLocations',
      component: WrixLocationsList,
      props: (route) => ({ storeName: '$_wrix_locations', query: route.query.query })
    },
    {
      path: 'wrix/new',
      name: 'newWrixLocation',
      component: WrixLocationView,
      props: (route) => ({ storeName: '$_wrix_locations', isNew: true })
    },
    {
      path: 'wrix/:id',
      name: 'wrixLocation',
      component: WrixLocationView,
      props: (route) => ({ storeName: '$_wrix_locations', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_wrix_locations/getWrixLocation', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'wrix/:id/clone',
      name: 'cloneWrixLocation',
      component: WrixLocationView,
      props: (route) => ({ storeName: '$_wrix_locations', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_wrix_locations/getWrixLocation', to.params.id).then(object => {
          next()
        })
      }
    },
    /**
     *  Advanced Access Configuration
     */
    {
      path: 'captive_portal',
      name: 'captive_portal',
      component: CaptivePortalView,
      props: (route) => ({ storeName: '$_bases', query: route.query.query })
    },
    {
      path: 'filters',
      name: 'filters',
      component: FilterEngineTabs,
      props: (route) => ({ storeName: '$_filters', query: route.query.query })
    },
    {
      path: 'billing_tiers',
      name: 'billing_tiers',
      component: BillingTiersList,
      props: (route) => ({ storeName: '$_billing_tiers', query: route.query.query })
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
    },
    {
      path: 'billing_tier/:id/clone',
      name: 'cloneBillingTier',
      component: BillingTierView,
      props: (route) => ({ storeName: '$_billing_tiers', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_billing_tiers/getBillingTier', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'pki_providers',
      name: 'pki_providers',
      component: PkiProvidersList,
      props: (route) => ({ storeName: '$_pki_providers', query: route.query.query })
    },
    {
      path: 'pki_providers/new/:providerType',
      name: 'newPkiProvider',
      component: PkiProviderView,
      props: (route) => ({ storeName: '$_pki_providers', isNew: true, providerType: route.params.providerType })
    },
    {
      path: 'pki_provider/:id',
      name: 'pki_provider',
      component: PkiProviderView,
      props: (route) => ({ storeName: '$_pki_providers', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_pki_providers/getPkiProvider', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'pki_provider/:id/clone',
      name: 'clonePkiProvider',
      component: PkiProviderView,
      props: (route) => ({ storeName: '$_pki_providers', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_pki_providers/getPkiProvider', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'provisionings',
      name: 'provisionings',
      component: ProvisioningsList,
      props: (route) => ({ storeName: '$_provisionings', query: route.query.query })
    },
    {
      path: 'provisionings/new/:provisioningType',
      name: 'newProvisioning',
      component: ProvisioningView,
      props: (route) => ({ storeName: '$_provisionings', isNew: true, provisioningType: route.params.provisioningType })
    },
    {
      path: 'provisioning/:id',
      name: 'provisioning',
      component: ProvisioningView,
      props: (route) => ({ storeName: '$_provisionings', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_provisionings/getProvisioning', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'provisioning/:id/clone',
      name: 'cloneProvisioning',
      component: ProvisioningView,
      props: (route) => ({ storeName: '$_provisionings', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_provisionings/getProvisioning', to.params.id).then(object => {
          next()
        })
      }
    },
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
      path: 'access_duration',
      name: 'access_duration',
      component: AccessDurationView,
      props: (route) => ({ storeName: '$_bases', query: route.query.query })
    },
    {
      path: 'device_registrations',
      name: 'device_registrations',
      component: DeviceRegistrationsList,
      props: (route) => ({ storeName: '$_device_registrations', query: route.query.query })
    },
    {
      path: 'device_registrations/new',
      name: 'newDeviceRegistration',
      component: DeviceRegistrationView,
      props: (route) => ({ storeName: '$_device_registrations', isNew: true })
    },
    {
      path: 'device_registration/:id',
      name: 'device_registration',
      component: DeviceRegistrationView,
      props: (route) => ({ storeName: '$_device_registrations', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_device_registrations/getDeviceRegistration', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'device_registration/:id/clone',
      name: 'cloneDeviceRegistration',
      component: DeviceRegistrationView,
      props: (route) => ({ storeName: '$_device_registrations', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_device_registrations/getDeviceRegistration', to.params.id).then(object => {
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
      path: 'networks',
      name: 'networks',
      component: NetworksTabs,
      props: (route) => ({ tab: 'network', query: route.query.query })
    },
    {
      path: 'network',
      name: 'network',
      component: NetworksTabs,
      props: (route) => ({ tab: 'network', query: route.query.query })
    },
    {
      path: 'interfaces',
      name: 'interfaces',
      component: NetworksTabs,
      props: (route) => ({ tab: 'interfaces', storeName: '$_interfaces', query: route.query.query })
    },
    {
      path: 'interface/:id',
      name: 'interface',
      component: InterfaceView,
      props: (route) => ({ storeName: '$_interfaces', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_interfaces/getInterface', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'interface/:id/clone',
      name: 'cloneInterface',
      component: InterfaceView,
      props: (route) => ({ storeName: '$_interfaces', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_interfaces/getInterface', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'interface/:id/new',
      name: 'newInterface',
      component: InterfaceView,
      props: (route) => ({ storeName: '$_interfaces', id: route.params.id, isNew: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_interfaces/getInterface', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'interfaces/routed_networks/new',
      name: 'newRoutedNetwork',
      component: RoutedNetworkView,
      props: (route) => ({ storeName: '$_routed_networks', isNew: true })
    },
    {
      path: 'interfaces/routed_network/:id',
      name: 'routed_network',
      component: RoutedNetworkView,
      props: (route) => ({ storeName: '$_routed_networks', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_routed_networks/getRoutedNetwork', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'interfaces/routed_network/:id/clone',
      name: 'cloneRoutedNetwork',
      component: RoutedNetworkView,
      props: (route) => ({ storeName: '$_routed_networks', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_routed_networks/getRoutedNetwork', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'inline',
      name: 'inline',
      component: NetworksTabs,
      props: (route) => ({ tab: 'inline', query: route.query.query })
    },
    {
      path: 'traffic_shapings',
      name: 'traffic_shapings',
      component: NetworksTabs,
      props: (route) => ({ tab: 'traffic_shapings', storeName: '$_traffic_shaping_policies', query: route.query.query })
    },
    {
      path: 'traffic_shaping/new/:role',
      name: 'newTrafficShaping',
      component: TrafficShapingView,
      props: (route) => ({ storeName: '$_traffic_shaping_policies', isNew: true, role: route.params.role })
    },
    {
      path: 'traffic_shaping/:id',
      name: 'traffic_shaping',
      component: TrafficShapingView,
      props: (route) => ({ storeName: '$_traffic_shaping_policies', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_traffic_shaping_policies/getTrafficShapingPolicy', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'fencing',
      name: 'fencing',
      component: NetworksTabs,
      props: (route) => ({ tab: 'fencing', query: route.query.query })
    },
    {
      path: 'parking',
      name: 'parking',
      component: NetworksTabs,
      props: (route) => ({ tab: 'parking', query: route.query.query })
    },
    {
      path: 'floating_devices',
      name: 'floating_devices',
      component: FloatingDevicesList,
      props: (route) => ({ storeName: '$_floatingdevices', query: route.query.query })
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
    {
      path: 'floating_device/:id/clone',
      name: 'cloneFloatingDevice',
      component: FloatingDeviceView,
      props: (route) => ({ storeName: '$_floatingdevices', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_floatingdevices/getFloatingDevice', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'snmp_traps',
      name: 'snmp_traps',
      component: SnmpTrapView,
      props: (route) => ({ storeName: '$_bases', query: route.query.query })
    },
    {
      path: 'certificates',
      redirect: 'certificate/http'
    },
    {
      path: 'certificate/:id',
      name: 'certificate',
      component: CertificatesView,
      props: (route) => ({ storeName: '$_certificates', id: route.params.id })
    },
    /**
     * Main Configuration
     */
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
    {
      path: 'advanced',
      name: 'advanced',
      component: MainTabs,
      props: (route) => ({ tab: 'advanced', query: route.query.query })
    },
    {
      path: 'maintenance_tasks',
      name: 'maintenance_tasks',
      component: MainTabs,
      props: (route) => ({ tab: 'maintenance_tasks', storeName: '$_maintenance_tasks', query: route.query.query })
    },
    {
      path: 'maintenance_task/:id',
      name: 'maintenance_task',
      component: MaintenanceTaskView,
      props: (route) => ({ storeName: '$_maintenance_tasks', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_maintenance_tasks/getMaintenanceTask', to.params.id).then(object => {
          next()
        })
      }
    },
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
    {
      path: 'active_active',
      name: 'active_active',
      component: ActiveActiveView,
      props: (route) => ({ query: route.query.query })
    },
    {
      path: 'radius',
      name: 'radius',
      component: RadiusView,
      props: (route) => ({ query: route.query.query })
    },
    {
      path: 'admin_roles',
      name: 'admin_roles',
      component: AdminRolesList,
      props: (route) => ({ storeName: '$_admin_roles', query: route.query.query })
    },
    {
      path: 'admin_roles/new',
      name: 'newAdminRole',
      component: AdminRoleView,
      props: (route) => ({ storeName: '$_admin_roles', isNew: true })
    },
    {
      path: 'admin_role/:id',
      name: 'admin_role',
      component: AdminRoleView,
      props: (route) => ({ storeName: '$_admin_roles', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_admin_roles/getAdminRole', to.params.id).then(object => {
          next()
        })
      }
    },
    {
      path: 'admin_role/:id/clone',
      name: 'cloneAdminRole',
      component: AdminRoleView,
      props: (route) => ({ storeName: '$_admin_roles', id: route.params.id, isClone: true }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_admin_roles/getAdminRole', to.params.id).then(object => {
          next()
        })
      }
    }
  ]
}

export default route
