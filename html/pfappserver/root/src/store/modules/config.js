/**
 * "config" store module
 */
import Vue from 'vue'
import { types } from '@/store'
import apiCall from '@/utils/api'
import duration from '@/utils/duration'
import i18n from '@/utils/locale'
import acl from '@/utils/acl'

const encodeURL = (url) => {
  if (Array.isArray(url)) {
    return url.map(segment => encodeURIComponent(segment.toString().replace('/', '~'))).join('/')
  } else {
    return url
  }
}

const api = {
  getAdminRoles () {
    return apiCall({ url: 'config/admin_roles', method: 'get', params: { limit: 1000 } })
  },
  getBaseActiveActive () {
    return apiCall({ url: 'config/base/active_active', method: 'get' })
  },
  getBaseFleetDM () {
    return apiCall({ url: 'config/base/fleetdm', method: 'get' })
  },
  getBaseAdvanced () {
    return apiCall({ url: 'config/base/advanced', method: 'get' })
  },
  getBaseAlerting () {
    return apiCall({ url: 'config/base/alerting', method: 'get' })
  },
  getBaseCaptivePortal () {
    return apiCall({ url: 'config/base/captive_portal', method: 'get' })
  },
  getBaseDatabase () {
    return apiCall({ url: 'config/base/database', method: 'get' })
  },
  getBaseDatabaseAdvanced () {
    return apiCall({ url: 'config/base/database_advanced', method: 'get' })
  },
  getBaseDatabaseEncryption () {
    return apiCall({ url: 'config/base/database_encryption', method: 'get' })
  },
  getBaseFencing () {
    return apiCall({ url: 'config/base/fencing', method: 'get' })
  },
  getBaseFingerbankDeviceChange () {
    return apiCall({ url: 'config/base/fingerbank_device_change', method: 'get' })
  },
  getBaseGeneral () {
    return apiCall({ url: 'config/base/general', method: 'get' })
  },
  getBaseGuestsAdminRegistration () {
    return apiCall({ url: 'config/base/guests_admin_registration', method: 'get' })
  },
  getBaseInline () {
    return apiCall({ url: 'config/base/inline', method: 'get' })
  },
  getBaseMseTab () {
    return apiCall({ url: 'config/base/mse_tab', method: 'get' })
  },
  getBaseNetwork () {
    return apiCall({ url: 'config/base/network', method: 'get' })
  },
  getBaseNodeImport () {
    return apiCall({ url: 'config/base/node_import', method: 'get' })
  },
  getBaseParking () {
    return apiCall({ url: 'config/base/parking', method: 'get' })
  },
  getBasePFDHCP () {
    return apiCall({ url: 'config/base/pfdhcp', method: 'get' })
  },
  getBasePorts () {
    return apiCall({ url: 'config/base/ports', method: 'get' })
  },
  getBaseProvisioning () {
    return apiCall({ url: 'config/base/provisioning', method: 'get' })
  },
  getBaseRadiusConfiguration () {
    return apiCall({ url: 'config/base/radius_configuration', method: 'get' })
  },
  getBaseDnsConfiguration () {
    return apiCall({ url: 'config/base/dns_configuration', method: 'get' })
  },
  getBaseServices () {
    return apiCall({ url: 'config/base/services', method: 'get' })
  },
  getBaseSNMPTraps () {
    return apiCall({ url: 'config/base/snmp_traps', method: 'get' })
  },
  getBaseWebServices () {
    return apiCall({ url: 'config/base/web_services', method: 'get' })
  },
  getBillingTiers () {
    return apiCall({ url: 'config/billing_tiers', method: 'get' })
  },
  getClouds () {
    return apiCall({ url: 'config/clouds', method: 'get' })
  },
  getConnectionProfiles () {
    return apiCall({ url: 'config/connection_profiles', method: 'get' })
  },
  getConnectors () {
    return apiCall({ url: 'config/connectors', method: 'get' })
  },
  getDomains () {
    return apiCall({ url: 'config/domains', method: 'get' })
  },
  getEventLoggers () {
    return apiCall({ url: 'config/event_loggers', method: 'get' })
  },
  getFilterEngines (collection) {
    return apiCall({ url: encodeURL(['config', 'filter_engines', collection]), method: 'get' })
  },
  getFirewalls () {
    return apiCall({ url: 'config/firewalls', method: 'get' })
  },
  getFloatingDevices () {
    return apiCall({ url: 'config/floating_devices', method: 'get' })
  },
  getInterfaces () {
    return apiCall({ url: 'config/interfaces', method: 'get' })
  },
  getLayer2Networks () {
    return apiCall({ url: 'config/l2_networks', method: 'get', params: { limit: 1000 } })
  },
  getNetworkBehaviorPolicies () {
    return apiCall({ url: 'config/network_behavior_policies', method: 'get' })
  },
  getMaintenanceTasks () {
    return apiCall({ url: 'config/maintenance_tasks', method: 'get' })
  },
  getMfas () {
    return apiCall({ url: 'config/mfas', method: 'get' })
  },
  getPkiCas () {
    return apiCall({ url: 'pki/cas', method: 'get', params: { limit: 1000 } })
  },
  getPkiProfiles () {
    return apiCall({ url: 'pki/profiles', method: 'get', params: { limit: 1000 } })
  },
  getPkiCerts () {
    return apiCall({ url: 'pki/certs', method: 'get', params: { limit: 1000 } })
  },
  getPkiScepServers () {
    return apiCall({ url: 'pki/scepservers', method: 'get', params: { limit: 1000 } })
  },
  getPkiProviders () {
    return apiCall({ url: 'config/pki_providers', method: 'get' })
  },
  getPortalModules () {
    return apiCall({ url: 'config/portal_modules', method: 'get', params: { limit: 1000 } })
  },
  getProvisionings () {
    return apiCall({ url: 'config/provisionings', method: 'get' })
  },
  getRadiusEaps () {
    return apiCall({ url: 'config/radiusd/eap_profiles', method: 'get' })
  },
  getRadiusFasts () {
    return apiCall({ url: 'config/radiusd/fast_profiles', method: 'get' })
  },
  getRadiusOcsps () {
    return apiCall({ url: 'config/radiusd/ocsp_profiles', method: 'get' })
  },
  getRadiusSsls () {
    return apiCall({ url: 'config/ssl_certificates', method: 'get' })
  },
  getRadiusTlss () {
    return apiCall({ url: 'config/radiusd/tls_profiles', method: 'get' })
  },
  getRealms () {
    return apiCall({ url: 'config/realms', method: 'get' })
  },
  getRemoteConnectionProfiles () {
    return apiCall({ url: 'config/remote_connection_profiles', method: 'get' })
  },
  getRoles () {
    return apiCall({ url: 'node_categories', method: 'get', params: { limit: 1000 } })
  },
  getRoutedNetworks () {
    return apiCall({ url: 'config/routed_networks', method: 'get', params: { limit: 1000 } })
  },
  getScans () {
    return apiCall({ url: 'config/scans', method: 'get' })
  },
  getSecurityEvents () {
    return apiCall({ url: 'config/security_events', method: 'get', params: { limit: 1000 } })
  },
  getSelfServices () {
    return apiCall({ url: 'config/self_services', method: 'get' })
  },
  getSources () {
    return apiCall({ url: 'config/sources', method: 'get', params: { limit: 1000 } })
  },
  getSsids () {
    return apiCall({ url: 'locationlogs/ssids', method: 'get' })
  },
  getSwitches () {
    return apiCall({ url: 'config/switches', method: 'get', params: { limit: 1000, raw: 1 } })
  },
  getSwitchGroups () {
    return apiCall({ url: 'config/switch_groups', method: 'get', params: { limit: 1000, raw: 1 } })
  },
  getSwitchGroupMembers (id) {
    return apiCall({ url: `config/switch_group/${id}/members`, method: 'get' })
  },
  getSwitchTemplates () {
    return apiCall({ url: 'config/template_switches', method: 'get' })
  },
  getSyslogForwarders () {
    return apiCall({ url: 'config/syslog_forwarders', method: 'get' })
  },
  getEventHandlers () {
    return apiCall({ url: 'config/event_handlers', method: 'get' })
  },
  getWrixLocations () {
    return apiCall({ url: 'wrix_locations', method: 'get' })
  },
  flattenCondition: (data) => {
    return apiCall.postQuiet('config/flatten_condition', data).then(response => {
      return response.data
    }).catch(err => {
      throw err
    })
  },
  parseCondition: (data) => {
    return apiCall.postQuiet('config/parse_condition', data).then(response => {
      return response.data
    }).catch(err => {
      throw err
    })
  }
}

const initialState = () => { // set intitial states to `false` (not `[]` or `{}`) to avoid infinite loop when response is empty.
  return {
    adminRoles: false,
    adminRolesStatus: '',
    baseActiveActive: false,
    baseActiveActiveStatus: '',
    baseFleetDM: false,
    baseFleetDMStatus: '',
    baseAdvanced: false,
    baseAdvancedStatus: '',
    baseAlerting: false,
    baseAlertingStatus: '',
    baseCaptivePortal: false,
    baseCaptivePortalStatus: '',
    baseDatabase: false,
    baseDatabaseAdvanced: false,
    baseDatabaseAdvancedStatus: '',
    baseDatabaseEncryption: false,
    baseDatabaseEncryptionStatus: '',
    baseDatabaseStatus: '',
    baseFencing: false,
    baseFencingStatus: '',
    baseFingerbankDeviceChange: false,
    baseFingerbankDeviceChangeStatus: '',
    baseGeneral: false,
    baseGeneralStatus: '',
    baseGuestsAdminRegistration: false,
    baseGuestsAdminRegistrationStatus: '',
    baseInline: false,
    baseInlineStatus: '',
    baseMseTab: false,
    baseMseTabStatus: '',
    baseNetwork: false,
    baseNetworkStatus: '',
    baseNodeImport: false,
    baseNodeImportStatus: '',
    basePFDHCP: false,
    basePFDHCPStatus: '',
    baseParking: false,
    baseParkingStatus: '',
    basePorts: false,
    basePortsStatus: '',
    baseProvisioning: false,
    baseProvisioningStatus: '',
    baseRadiusConfiguration: false,
    baseRadiusConfigurationStatus: '',
    baseDnsConfiguration: false,
    baseDnsConfigurationStatus: '',
    baseSNMPTraps: false,
    baseSNMPTrapsStatus: '',
    baseServices: false,
    baseServicesStatus: '',
    baseWebServices: false,
    baseWebServicesStatus: '',
    billingTiers: false,
    billingTiersStatus: '',
    clouds: false,
    cloudsStatus: '',
    connectionProfiles: false,
    connectionProfilesStatus: '',
    connectors: false,
    connectorsStatus: '',
    domains: false,
    domainsStatus: '',
    eventLoggers: false,
    eventLoggersStatus: '',
    filterEngines: false,
    filterEnginesStatus: '',
    firewalls: false,
    firewallsStatus: '',
    floatingDevices: false,
    floatingDevicesStatus: '',
    interfaces: false,
    interfacesStatus: '',
    layer2Networks: false,
    layer2NetworksStatus: '',
    maintenanceTasks: false,
    maintenanceTasksStatus: '',
    mfas: false,
    mfasStatus: '',
    networkBehaviorPolicies: false,
    networkBehaviorPoliciesStatus: '',
    pkiCas: false,
    pkiCasStatus: '',
    pkiProfiles: false,
    pkiProfilesStatus: '',
    pkiCerts: false,
    pkiCertsStatus: '',
    pkiScepServers: false,
    pkiScepServersStatus: '',
    pkiProviders: false,
    pkiProvidersStatus: '',
    portalModules: false,
    portalModulesStatus: '',
    provisionings: false,
    provisioningsStatus: '',
    radiusEaps: false,
    radiusEapsStatus: '',
    radiusFasts: false,
    radiusFastsStatus: '',
    radiusOcsps: false,
    radiusOcspsStatus: '',
    radiusSsls: false,
    radiusSslsStatus: '',
    radiusTlss: false,
    radiusTlssStatus: '',
    realms: {},
    realmsStatus: '',
    roles: false,
    rolesStatus: '',
    routedNetworks: false,
    routedNetworksStatus: '',
    scans: false,
    scansStatus: '',
    securityEvents: false,
    securityEventsStatus: '',
    selfServices: false,
    selfServicesStatus: '',
    sources: false,
    sourcesStatus: '',
    ssids: false,
    ssidsStatus: '',
    switchGroups: false,
    switchGroupsStatus: '',
    switchTemplates: false,
    switchTemplatesStatus: '',
    switches: false,
    switchesStatus: '',
    syslogForwarders: false,
    syslogForwardersStatus: '',
    eventHandlers: false,
    eventHandlersStatus: '',
    wrixLocations: false,
    wrixLocationsStatus: ''
  }
}

const helpers = {
  sortSecurityEvents: (securityEvents) => {
    let sortedIds = Object.keys(securityEvents).sort((a, b) => {
      var aDesc = securityEvents[a].desc
      var bDesc = securityEvents[b].desc
      if (a === 'defaults') {
        return -1
      } else if (b === 'defaults') {
        return 1
      } else if (!aDesc && !bDesc) {
        return a.localeCompare(b)
      } else if (!securityEvents[b].desc) {
        return -1
      } else if (!securityEvents[a].desc) {
        return 1
      } else {
        return aDesc.localeCompare(bDesc)
      }
    })
    let sortedSecurityEvents = []
    for (let id of sortedIds) {
      sortedSecurityEvents.push(securityEvents[id])
    }
    return sortedSecurityEvents
  }
}

const getters = {
  isLoadingAdminRoles: state => {
    return state.adminRolesStatus === types.LOADING
  },
  isLoadingBaseActiveActive: state => {
    return state.baseActiveActiveStatus === types.LOADING
  },
  isLoadingBaseFleetDM: state => {
    return state.baseFleetDMStatus === types.LOADING
  },
  isLoadingBaseAdvanced: state => {
    return state.baseAdvancedStatus === types.LOADING
  },
  isLoadingBaseAlerting: state => {
    return state.baseAlertingStatus === types.LOADING
  },
  isLoadingBaseCaptivePortal: state => {
    return state.baseCaptivePortalStatus === types.LOADING
  },
  isLoadingBaseDatabase: state => {
    return state.baseDatabaseStatus === types.LOADING
  },
  isLoadingBaseDatabaseAdvanced: state => {
    return state.baseDatabaseAdvancedStatus === types.LOADING
  },
  isLoadingBaseDatabaseEncryption: state => {
    return state.baseDatabaseEncryptionStatus === types.LOADING
  },
  isLoadingBaseFencing: state => {
    return state.baseFencingStatus === types.LOADING
  },
  isLoadingBaseFingerbankDeviceChange: state => {
    return state.baseFingerbankDeviceChangeStatus === types.LOADING
  },
  isLoadingBaseGeneral: state => {
    return state.baseGeneralStatus === types.LOADING
  },
  isLoadingBaseGuestsAdminRegistration: state => {
    return state.baseGuestsAdminRegistrationStatus === types.LOADING
  },
  isLoadingBaseInline: state => {
    return state.baseInlineStatus === types.LOADING
  },
  isLoadingBaseMseTab: state => {
    return state.baseMseTabStatus === types.LOADING
  },
  isLoadingBaseNetwork: state => {
    return state.baseNetworkStatus === types.LOADING
  },
  isLoadingBaseNodeImport: state => {
    return state.baseNodeImportStatus === types.LOADING
  },
  isLoadingBaseParking: state => {
    return state.baseParkingStatus === types.LOADING
  },
  isLoadingBasePFDHCP: state => {
    return state.basePFDHCPStatus === types.LOADING
  },
  isLoadingBasePorts: state => {
    return state.basePortsStatus === types.LOADING
  },
  isLoadingBaseProvisioning: state => {
    return state.baseProvisioningStatus === types.LOADING
  },
  isLoadingBaseRadiusConfiguration: state => {
    return state.baseRadiusConfigurationStatus === types.LOADING
  },
  isLoadingBaseServices: state => {
    return state.baseServicesStatus === types.LOADING
  },
  isLoadingBaseSNMPTraps: state => {
    return state.baseSNMPTrapsStatus === types.LOADING
  },
  isLoadingBaseWebServices: state => {
    return state.baseWebServicesStatus === types.LOADING
  },
  isLoadingBillingTiers: state => {
    return state.billingTiersStatus === types.LOADING
  },
  isLoadingClouds: state => {
    return state.cloudsStatus === types.LOADING
  },
  isLoadingConnectionProfiles: state => {
    return state.connectionProfilesStatus === types.LOADING
  },
  isLoadingConnectors: state => {
    return state.connectorsStatus === types.LOADING
  },
  isLoadingSelfServices: state => {
    return state.selfServicesStatus === types.LOADING
  },
  isLoadingDomains: state => {
    return state.domainsStatus === types.LOADING
  },
  isLoadingEventLoggers: state => {
    return state.eventLoggersStatus === types.LOADING
  },
  isLoadingFilterEngines: state => {
    return state.filterEnginesStatus === types.LOADING
  },
  isLoadingFirewalls: state => {
    return state.firewallsStatus === types.LOADING
  },
  isLoadingFloatingDevices: state => {
    return state.floatingDevicesStatus === types.LOADING
  },
  isLoadingInterfaces: state => {
    return state.interfacesStatus === types.LOADING
  },
  isLoadingLayer2Networks: state => {
    return state.layer2NetworksStatus === types.LOADING
  },
  isLoadingMaintenanceTasks: state => {
    return state.maintenanceTasksStatus === types.LOADING
  },
  isLoadingMfas: state => {
    return state.mfasStatus === types.LOADING
  },
  isLoadingNetworkBehaviorPolicies: state => {
    return state.networkBehaviorPoliciesStatus === types.LOADING
  },
  isLoadingPkiCas: state => {
    return state.pkiCasStatus === types.LOADING
  },
  isLoadingPkiProfiles: state => {
    return state.pkiProfilesStatus === types.LOADING
  },
  isLoadingPkiCerts: state => {
    return state.pkiCertsStatus === types.LOADING
  },
  isLoadingPkiScepServers: state => {
    return state.pkiScepServersStatus === types.LOADING
  },
  isLoadingPkiProviders: state => {
    return state.pkiProvidersStatus === types.LOADING
  },
  isLoadingPortalModules: state => {
    return state.portalModulesStatus === types.LOADING
  },
  isLoadingProvisionings: state => {
    return state.provisioningsStatus === types.LOADING
  },
  isLoadingRadiusEaps: state => {
    return state.radiusEapsStatus === types.LOADING
  },
  isLoadingRadiusFasts: state => {
    return state.radiusFastsStatus === types.LOADING
  },
  isLoadingRadiusOcsps: state => {
    return state.radiusOcspsStatus === types.LOADING
  },
  isLoadingRadiusSsls: state => {
    return state.radiusSslsStatus === types.LOADING
  },
  isLoadingRadiusTlss: state => {
    return state.radiusTlssStatus === types.LOADING
  },
  isLoadingRealms: state => {
    return state.realmsStatus === types.LOADING
  },
  isLoadingRoles: state => {
    return state.rolesStatus === types.LOADING
  },
  isLoadingRoutedNetworks: state => {
    return state.routedNetworksStatus === types.LOADING
  },
  isLoadingScans: state => {
    return state.scansStatus === types.LOADING
  },
  isLoadingSecurityEvents: state => {
    return state.securityEventsStatus === types.LOADING
  },
  isLoadingSources: state => {
    return state.sourcesStatus === types.LOADING
  },
  isLoadingSsids: state => {
    return state.ssidsStatus === types.LOADING
  },
  isLoadingSwitches: state => {
    return state.switchesStatus === types.LOADING
  },
  isLoadingSwitchGroups: state => {
    return state.switchGroupsStatus === types.LOADING
  },
  isLoadingSwitchTemplates: state => {
    return state.switchTemplatesStatus === types.LOADING
  },
  isLoadingSyslogForwarders: state => {
    return state.syslogForwardersStatus === types.LOADING
  },
  isLoadingEventHandlers: state => {
    return state.eventHandlersStatus === types.LOADING
  },
  isLoadingWrixLocations: state => {
    return state.wrixLocationsStatus === types.LOADING
  },
  accessDurationsList: state => {
    if (!state.baseGuestsAdminRegistration || !('access_duration_choices' in state.baseGuestsAdminRegistration)) return []
    return state.baseGuestsAdminRegistration.access_duration_choices.split(',').map((accessDuration) => {
      return duration.deserialize(accessDuration)
    }).sort((a, b) => {
      return (a.sort > b.sort) ? 1 : -1
    })
  },
  adminRolesList: state => {
    if (!state.adminRoles) return []
    return state.adminRoles.map((item) => {
      return { value: item.id, text: item.id }
    })
  },
  domainsList: state => {
    if (!state.domains) return []
    return state.domains.map((item) => {
      return { value: item.id, text: item.id }
    })
  },
  connectionProfilesList: state => {
    if (!state.connectionProfiles) return []
    return state.connectionProfiles.map((item) => {
      return { value: item.id, text: ((item.description) ? `${item.id} - ${item.description}` : `${item.id}`) }
    })
  },
  portalModulesList: state => {
    if (!state.portalModules) return []
    return state.portalModules.map((item) => {
      return { value: item.id, text: item.description }
    })
  },
  realmsList: state => {
    let list = []
    for (let i in state.realms) {
      list = [ ...list, ...state.realms[i].map((item) => {
        return { value: item.id, text: item.id }
      }) ]
    }
    return list
  },
  rolesList: state => {
    if (!state.roles) return []
    return [
      ...[{ value: null, text: i18n.t('empty - None') }],
      ...state.roles.map((item) => {
        return { value: item.category_id, text: ((item.notes) ? `${item.name} - ${item.notes}` : `${item.name}`) }
      })
    ]
  },
  rootPortalModulesList: state => {
    if (!state.portalModules) return []
    return state.portalModules.filter(item => item.type === 'Root').map((item) => {
      return { value: item.id, text: item.description }
    })
  },
  sourcesList: state => {
    if (!state.sources) return []
    return state.sources.map((item) => {
      return { value: item.id, text: ((item.description) ? `${item.id} - ${item.description}` : `${item.id}`) }
    })
  },
  ssidsList: state => {
    if (!state.ssids) return []
    return state.ssids.map((item) => {
      return { value: item.ssid, text: item.ssid }
    })
  },
  switchGroupsList: state => {
    if (!state.switchGroups) return []
    return state.switchGroups.map((item) => {
      return { value: item.id, text: `${item.id} - ${item.description}` }
    })
  },
  switchesList: state => {
    if (!state.switches) return []
    return [...(new Set(state.switches))]
      .sort((a, b) => {
        if (+a.id === 0) {
          return 1
        }
        if (+b.id === 0) {
          return -1
        }
        return a.description.localeCompare(b.description)
      })
      .map((item) => {
        return { value: item.id, text: `${item.id} - ${item.description}` }
      })
  },
  securityEventsList: state => {
    return helpers.sortSecurityEvents(state.securityEvents).filter(securityEvent => securityEvent.enabled === 'Y').map((item) => {
      return { value: item.id, text: item.desc }
    })
  },
  sortedSecurityEvents: state => {
    return helpers.sortSecurityEvents(state.securityEvents)
  }
}

const actions = {
  getAdminRoles: ({ state, getters, commit }) => {
    if (getters.isLoadingAdminRoles) {
      return Promise.resolve(state.adminRoles)
    }
    if (acl.$can('read', 'admin_roles')) {
      if (!state.adminRoles) {
        commit('ADMIN_ROLES_REQUEST')
        return api.getAdminRoles().then(response => {
          commit('ADMIN_ROLES_UPDATED', response.data.items)
          return state.adminRoles
        })
      } else {
        return Promise.resolve(state.adminRoles)
      }
    } else {
      commit('ADMIN_ROLES_UPDATED', [])
      return state.adminRoles
    }
  },
  resetAdminRoles: ({ state, getters, commit, dispatch }) => {
    if (!getters.isLoadingAdminRoles && state.adminRoles) {
      commit('ADMIN_ROLES_UPDATED', false)
      dispatch('getAdminRoles')
    }
  },
  getBaseActiveActive: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseActiveActive) {
      return Promise.resolve(state.baseActiveActive)
    }
    if (!state.baseActiveActive) {
      commit('BASE_ACTIVE_ACTIVE_REQUEST')
      return api.getBaseActiveActive().then(response => {
        commit('BASE_ACTIVE_ACTIVE_UPDATED', response.data.item)
        return state.baseActiveActive
      })
    } else {
      return Promise.resolve(state.baseActiveActive)
    }
  },
  getBaseFleetDM: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseFleetDM) {
      return Promise.resolve(state.baseFleetDM)
    }
    if (!state.baseFleetDM) {
      commit('BASE_FLEETDM_REQUEST')
      return api.getBaseFleetDM().then(response => {
        commit('BASE_FLEETDM_UPDATED', response.data.item)
        return state.baseFleetDM
      })
    } else {
      return Promise.resolve(state.baseFleetDM)
    }
  },
  getBaseAdvanced: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseAdvanced) {
      return Promise.resolve(state.baseAdvanced)
    }
    if (!state.baseAdvanced) {
      commit('BASE_ADVANCED_REQUEST')
      return api.getBaseAdvanced().then(response => {
        commit('BASE_ADVANCED_UPDATED', response.data.item)
        return state.baseAdvanced
      })
    } else {
      return Promise.resolve(state.baseAdvanced)
    }
  },
  getBaseAlerting: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseAlerting) {
      return Promise.resolve(state.baseAlerting)
    }
    if (!state.baseAlerting) {
      commit('BASE_ALERTING_REQUEST')
      return api.getBaseAlerting().then(response => {
        commit('BASE_ALERTING_UPDATED', response.data.item)
        return state.baseAlerting
      })
    } else {
      return Promise.resolve(state.baseAlerting)
    }
  },
  getBaseCaptivePortal: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseCaptivePortal) {
      return Promise.resolve(state.baseCaptivePortal)
    }
    if (!state.baseCaptivePortal) {
      commit('BASE_CAPTIVE_PORTAL_REQUEST')
      return api.getBaseCaptivePortal().then(response => {
        commit('BASE_CAPTIVE_PORTAL_UPDATED', response.data.item)
        return state.baseCaptivePortal
      })
    } else {
      return Promise.resolve(state.baseCaptivePortal)
    }
  },
  getBaseDatabase: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseDatabase) {
      return Promise.resolve(state.baseDatabase)
    }
    if (!state.baseDatabase) {
      commit('BASE_DATABASE_REQUEST')
      return api.getBaseDatabase().then(response => {
        commit('BASE_DATABASE_UPDATED', response.data.item)
        return state.baseDatabase
      })
    } else {
      return Promise.resolve(state.baseDatabase)
    }
  },
  getBaseDatabaseAdvanced: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseDatabaseAdvanced) {
      return Promise.resolve(state.baseDatabaseAdvanced)
    }
    if (!state.baseDatabaseAdvanced) {
      commit('BASE_DATABASE_ADVANCED_REQUEST')
      return api.getBaseDatabaseAdvanced().then(response => {
        commit('BASE_DATABASE_ADVANCED_UPDATED', response.data.item)
        return state.baseDatabaseAdvanced
      })
    } else {
      return Promise.resolve(state.baseDatabaseAdvanced)
    }
  },
  getBaseDatabaseEncryption: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseDatabaseEncryption) {
      return Promise.resolve(state.baseDatabaseEncryption)
    }
    if (!state.baseDatabaseEncryption) {
      commit('BASE_DATABASE_ENCRYPTION_REQUEST')
      return api.getBaseDatabaseEncryption().then(response => {
        commit('BASE_DATABASE_ENCRYPTION_UPDATED', response.data.item)
        return state.baseDatabaseEncryption
      })
    } else {
      return Promise.resolve(state.baseDatabaseEncryption)
    }
  },
  getBaseFencing: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseFencing) {
      return Promise.resolve(state.baseFencing)
    }
    if (!state.baseFencing) {
      commit('BASE_FENCING_REQUEST')
      return api.getBaseFencing().then(response => {
        commit('BASE_FENCING_UPDATED', response.data.item)
        return state.baseFencing
      })
    } else {
      return Promise.resolve(state.baseFencing)
    }
  },
  getBaseFingerbankDeviceChange: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseFingerbankDeviceChange) {
      return Promise.resolve(state.baseFingerbankDeviceChange)
    }
    if (!state.baseFingerbankDeviceChange) {
      commit('BASE_FINGERBANK_DEVICE_CHANGE_REQUEST')
      return api.getBaseFingerbankDeviceChange().then(response => {
        commit('BASE_FINGERBANK_DEVICE_CHANGE_UPDATED', response.data.item)
        return state.baseFingerbankDeviceChange
      })
    } else {
      return Promise.resolve(state.baseFingerbankDeviceChange)
    }
  },
  getBaseGeneral: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseGeneral) {
      return Promise.resolve(state.baseGeneral)
    }
    if (!state.baseGeneral) {
      commit('BASE_GENERAL_REQUEST')
      return api.getBaseGeneral().then(response => {
        commit('BASE_GENERAL_UPDATED', response.data.item)
        return state.baseGeneral
      })
    } else {
      return Promise.resolve(state.baseGeneral)
    }
  },
  getBaseGuestsAdminRegistration: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseGuestsAdminRegistration) {
      return Promise.resolve(state.baseGuestsAdminRegistration)
    }
    if (acl.$can('read', 'configuration_main')) {
      if (!state.baseGuestsAdminRegistration) {
        commit('BASE_GUESTS_ADMIN_REGISTRATION_REQUEST')
        return api.getBaseGuestsAdminRegistration().then(response => {
          commit('BASE_GUESTS_ADMIN_REGISTRATION_UPDATED', response.data.item)
          return state.baseGuestsAdminRegistration
        })
      } else {
        return Promise.resolve(state.baseGuestsAdminRegistration)
      }
    } else {
      commit('BASE_GUESTS_ADMIN_REGISTRATION_UPDATED', {})
      return Promise.resolve(state.baseGuestsAdminRegistration)
    }
  },
  getBaseInline: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseInline) {
      return Promise.resolve(state.baseInline)
    }
    if (!state.baseInline) {
      commit('BASE_INLINE_REQUEST')
      return api.getBaseInline().then(response => {
        commit('BASE_INLINE_UPDATED', response.data.item)
        return state.baseInline
      })
    } else {
      return Promise.resolve(state.baseInline)
    }
  },
  getBaseMseTab: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseMseTab) {
      return Promise.resolve(state.baseMseTab)
    }
    if (!state.baseMseTab) {
      commit('BASE_MSE_TAB_REQUEST')
      return api.getBaseMseTab().then(response => {
        commit('BASE_MSE_TAB_UPDATED', response.data.item)
        return state.baseMseTab
      })
    } else {
      return Promise.resolve(state.baseMseTab)
    }
  },
  getBaseNetwork: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseNetwork) {
      return Promise.resolve(state.baseNetwork)
    }
    if (!state.baseNetwork) {
      commit('BASE_NETWORK_REQUEST')
      return api.getBaseNetwork().then(response => {
        commit('BASE_NETWORK_UPDATED', response.data.item)
        return state.baseNetwork
      })
    } else {
      return Promise.resolve(state.baseNetwork)
    }
  },
  getBaseNodeImport: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseNodeImport) {
      return Promise.resolve(state.baseNodeImport)
    }
    if (!state.baseNodeImport) {
      commit('BASE_NODE_IMPORT_REQUEST')
      return api.getBaseNodeImport().then(response => {
        commit('BASE_NODE_IMPORT_UPDATED', response.data.item)
        return state.baseNodeImport
      })
    } else {
      return Promise.resolve(state.baseNodeImport)
    }
  },
  getBaseParking: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseParking) {
      return Promise.resolve(state.baseParking)
    }
    if (!state.baseParking) {
      commit('BASE_PARKING_REQUEST')
      return api.getBaseParking().then(response => {
        commit('BASE_PARKING_UPDATED', response.data.item)
        return state.baseParking
      })
    } else {
      return Promise.resolve(state.baseParking)
    }
  },
  getBasePFDHCP: ({ state, getters, commit }) => {
    if (getters.isLoadingBasePFDHCP) {
      return Promise.resolve(state.basePFDHCP)
    }
    if (!state.basePFDHCP) {
      commit('BASE_PFDHCP_REQUEST')
      return api.getBasePFDHCP().then(response => {
        commit('BASE_PFDHCP_UPDATED', response.data.item)
        return state.basePFDHCP
      })
    } else {
      return Promise.resolve(state.basePFDHCP)
    }
  },
  getBasePorts: ({ state, getters, commit }) => {
    if (getters.isLoadingBasePorts) {
      return Promise.resolve(state.basePorts)
    }
    if (!state.basePorts) {
      commit('BASE_PORTS_REQUEST')
      return api.getBasePorts().then(response => {
        commit('BASE_PORTS_UPDATED', response.data.item)
        return state.basePorts
      })
    } else {
      return Promise.resolve(state.basePorts)
    }
  },
  getBaseProvisioning: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseProvisioning) {
      return Promise.resolve(state.baseProvisioning)
    }
    if (!state.baseProvisioning) {
      commit('BASE_PROVISIONING_REQUEST')
      return api.getBaseProvisioning().then(response => {
        commit('BASE_PROVISIONING_UPDATED', response.data.item)
        return state.baseProvisioning
      })
    } else {
      return Promise.resolve(state.baseProvisioning)
    }
  },
  getBaseRadiusConfiguration: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseRadiusConfiguration) {
      return Promise.resolve(state.baseRadiusConfiguration)
    }
    if (!state.baseRadiusConfiguration) {
      commit('BASE_RADIUS_CONFIGURATION_REQUEST')
      return api.getBaseRadiusConfiguration().then(response => {
        commit('BASE_RADIUS_CONFIGURATION_UPDATED', response.data.item)
        return state.baseRadiusConfiguration
      })
    } else {
      return Promise.resolve(state.baseRadiusConfiguration)
    }
  },
  getBaseDnsConfiguration: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseDnsConfiguration) {
      return Promise.resolve(state.baseDnsConfiguration)
    }
    if (!state.baseDnsConfiguration) {
      commit('BASE_DNS_CONFIGURATION_REQUEST')
      return api.getBaseDnsConfiguration().then(response => {
        commit('BASE_DNS_CONFIGURATION_UPDATED', response.data.item)
        return state.baseDnsConfiguration
      })
    } else {
      return Promise.resolve(state.baseDnsConfiguration)
    }
  },
  getBaseServices: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseServices) {
      return Promise.resolve(state.baseServices)
    }
    if (!state.baseServices) {
      commit('BASE_SERVICES_REQUEST')
      return api.getBaseServices().then(response => {
        commit('BASE_SERVICES_UPDATED', response.data.item)
        return state.baseServices
      })
    } else {
      return Promise.resolve(state.baseServices)
    }
  },
  getBaseSNMPTraps: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseSNMPTraps) {
      return Promise.resolve(state.baseSNMPTraps)
    }
    if (!state.baseSNMPTraps) {
      commit('BASE_SNMP_TRAPS_REQUEST')
      return api.getBaseSNMPTraps().then(response => {
        commit('BASE_SNMP_TRAPS_UPDATED', response.data.item)
        return state.baseSNMPTraps
      })
    } else {
      return Promise.resolve(state.baseSNMPTraps)
    }
  },
  getBaseWebServices: ({ state, getters, commit }) => {
    if (getters.isLoadingBaseWebServices) {
      return Promise.resolve(state.baseWebServices)
    }
    if (!state.baseWebServices) {
      commit('BASE_WEB_SERVICES_REQUEST')
      return api.getBaseWebServices().then(response => {
        commit('BASE_WEB_SERVICES_UPDATED', response.data.item)
        return state.baseWebServices
      })
    } else {
      return Promise.resolve(state.baseWebServices)
    }
  },
  getBillingTiers: ({ state, getters, commit }) => {
    if (getters.isLoadingBillingTiers) {
      return Promise.resolve(state.billingTiers)
    }
    if (!state.billingTiers) {
      commit('BILLING_TIERS_REQUEST')
      return api.getBillingTiers().then(response => {
        commit('BILLING_TIERS_UPDATED', response.data.items)
        return state.billingTiers
      })
    } else {
      return Promise.resolve(state.billingTiers)
    }
  },
  getClouds: ({ state, getters, commit }) => {
    if (getters.isLoadingClouds) {
      return Promise.resolve(state.clouds)
    }
    if (!state.clouds) {
      commit('CLOUDS_REQUEST')
      return api.getClouds().then(response => {
        commit('CLOUDS_UPDATED', response.data.items)
        return state.clouds
      })
    } else {
      return Promise.resolve(state.clouds)
    }
  },
  getConnectionProfiles: ({ state, getters, commit }) => {
    if (getters.isLoadingConnectionProfiles) {
      return Promise.resolve(state.connectionProfiles)
    }
    if (!state.connectionProfiles) {
      commit('CONNECTION_PROFILES_REQUEST')
      return api.getConnectionProfiles().then(response => {
        commit('CONNECTION_PROFILES_UPDATED', response.data.items)
        return state.connectionProfiles
      })
    } else {
      return Promise.resolve(state.connectionProfiles)
    }
  },
  getConnectors: ({ state, getters, commit }) => {
    if (getters.isLoadingConnectors) {
      return Promise.resolve(state.connectors)
    }
    if (!state.connectors) {
      commit('CONNECTORS_REQUEST')
      return api.getConnectors().then(response => {
        commit('CONNECTORS_UPDATED', response.data.items)
        return state.connectors
      })
    } else {
      return Promise.resolve(state.connectors)
    }
  },
  getSelfServices: ({ state, getters, commit }) => {
    if (getters.isLoadingSelfServices) {
      return Promise.resolve(state.selfServices)
    }
    if (!state.selfServices) {
      commit('SELF_SERVICES_REQUEST')
      return api.getSelfServices().then(response => {
        commit('SELF_SERVICES_UPDATED', response.data.items)
        return state.selfServices
      })
    } else {
      return Promise.resolve(state.selfServices)
    }
  },
  getDomains: ({ state, getters, commit }) => {
    if (getters.isLoadingDomains) {
      return Promise.resolve(state.domains)
    }
    if (!state.domains) {
      commit('DOMAINS_REQUEST')
      return api.getDomains().then(response => {
        commit('DOMAINS_UPDATED', response.data.items)
        return state.domains
      })
    } else {
      return Promise.resolve(state.domains)
    }
  },
  getEventLoggers: ({ state, getters, commit }) => {
    if (getters.isLoadingEventLoggers) {
      return Promise.resolve(state.eventLoggers)
    }
    if (!state.eventLoggers) {
      commit('EVENT_LOGGERS_REQUEST')
      return api.getEventLoggers().then(response => {
        commit('EVENT_LOGGERS_UPDATED', response.data.items)
        return state.eventLoggers
      })
    } else {
      return Promise.resolve(state.eventLoggers)
    }
  },
  getFilterEngines: ({ state, getters, commit }, collection) => {
    if (getters.isLoadingFilterEngines) {
      return Promise.resolve(state.filterEngines[collection])
    }
    if (!state.filterEngines || !state.filterEngines[collection]) {
      commit('FILTER_ENGINES_REQUEST')
      return api.getFilterEngines(collection).then(response => {
        commit('FILTER_ENGINES_UPDATED', { collection, filterEngines: response.data.items })
        return state.filterEngines[collection]
      })
    } else {
      return Promise.resolve(state.filterEngines[collection])
    }
  },
  getFirewalls: ({ state, getters, commit }) => {
    if (getters.isLoadingFirewalls) {
      return Promise.resolve(state.firewalls)
    }
    if (!state.firewalls) {
      commit('FIREWALLS_REQUEST')
      return api.getFirewalls().then(response => {
        commit('FIREWALLS_UPDATED', response.data.items)
        return state.firewalls
      })
    } else {
      return Promise.resolve(state.firewalls)
    }
  },
  getFloatingDevices: ({ state, getters, commit }) => {
    if (getters.isLoadingFloatingDevices) {
      return Promise.resolve(state.floatingDevices)
    }
    if (!state.floatingDevices) {
      commit('FLOATING_DEVICES_REQUEST')
      return api.getFloatingDevices().then(response => {
        commit('FLOATING_DEVICES_UPDATED', response.data.items)
        return state.floatingDevices
      })
    } else {
      return Promise.resolve(state.floatingDevices)
    }
  },
  getInterfaces: ({ state, getters, commit }) => {
    if (getters.isLoadingInterfaces) {
      return Promise.resolve(state.interfaces)
    }
    if (!state.interfaces) {
      commit('INTERFACES_REQUEST')
      return api.getInterfaces().then(response => {
        commit('INTERFACES_UPDATED', response.data.items)
        return state.interfaces
      })
    } else {
      return Promise.resolve(state.interfaces)
    }
  },
  getLayer2Networks: ({ state, getters, commit }) => {
    if (getters.isLoadingLayer2Networks) {
      return Promise.resolve(state.layer2Networks)
    }
    if (!state.layer2Networks) {
      commit('LAYER2_NETWORKS_REQUEST')
      return api.getLayer2Networks().then(response => {
        commit('LAYER2_NETWORKS_UPDATED', response.data.items)
        return state.layer2Networks
      })
    } else {
      return Promise.resolve(state.layer2Networks)
    }
  },
  getMaintenanceTasks: ({ state, getters, commit }) => {
    if (getters.isLoadingMaintenanceTasks) {
      return Promise.resolve(state.maintenanceTasks)
    }
    if (!state.maintenanceTasks) {
      commit('MAINTENANCE_TASKS_REQUEST')
      return api.getMaintenanceTasks().then(response => {
        commit('MAINTENANCE_TASKS_UPDATED', response.data.items)
        return state.maintenanceTasks
      })
    } else {
      return Promise.resolve(state.maintenanceTasks)
    }
  },
  getMfas: ({ state, getters, commit }) => {
    if (getters.isLoadingMfas) {
      return Promise.resolve(state.mfas)
    }
    if (!state.mfas) {
      commit('MFAS_REQUEST')
      return api.getMfas().then(response => {
        commit('MFAS_UPDATED', response.data.items)
        return state.mfas
      })
    } else {
      return Promise.resolve(state.mfas)
    }
  },
  getNetworkBehaviorPolicies: ({ state, getters, commit }) => {
    if (getters.isLoadingNetworkBehaviorPolicies) {
      return Promise.resolve(state.networkBehaviorPolicies)
    }
    if (!state.networkBehaviorPolicies) {
      commit('NETWORK_BEHAVIOR_POLICIES_REQUEST')
      return api.getNetworkBehaviorPolicies().then(response => {
        commit('NETWORK_BEHAVIOR_POLICIES_UPDATED', response.data.items)
        return state.networkBehaviorPolicies
      })
    } else {
      return Promise.resolve(state.networkBehaviorPolicies)
    }
  },
  getPkiCas: ({ state, getters, commit }) => {
    if (getters.isLoadingPkiCas) {
      return Promise.resolve(state.pkiCas)
    }
    if (!state.pkiCas) {
      commit('PKI_CAS_REQUEST')
      return api.getPkiCas().then(response => {
        const { data: { items = [] } = {} } = response
        commit('PKI_CAS_UPDATED', items || [])
        return state.pkiCas
      })
    } else {
      return Promise.resolve(state.pkiCas)
    }
  },
  resetPkiCas: ({ state, commit }) => {
    if (state.pkiCas) {
      commit('PKI_CAS_RESET')
    }
  },
  getPkiProfiles: ({ state, getters, commit }) => {
    if (getters.isLoadingPkiProfiles) {
      return Promise.resolve(state.pkiProfiles)
    }
    if (!state.pkiProfiles) {
      commit('PKI_PROFILES_REQUEST')
      return api.getPkiProfiles().then(response => {
        const { data: { items = [] } = {} } = response
        commit('PKI_PROFILES_UPDATED', items || [])
        return state.pkiProfiles
      })
    } else {
      return Promise.resolve(state.pkiProfiles)
    }
  },
  resetPkiProfiles: ({ state, commit }) => {
    if (state.pkiProfiles) {
      commit('PKI_PROFILES_RESET')
    }
  },
  getPkiCerts: ({ state, getters, commit }) => {
    if (getters.isLoadingPkiCerts) {
      return Promise.resolve(state.pkiCerts)
    }
    if (!state.pkiCerts) {
      commit('PKI_CERTS_REQUEST')
      return api.getPkiCerts().then(response => {
        const { data: { items = [] } = {} } = response
        commit('PKI_CERTS_UPDATED', items || [])
        return state.pkiCerts
      })
    } else {
      return Promise.resolve(state.pkiCerts)
    }
  },
  resetPkiCerts: ({ state, commit }) => {
    if (state.pkiCerts) {
      commit('PKI_CERTS_RESET')
    }
  },
  getPkiScepServers: ({ state, getters, commit }) => {
    if (getters.isLoadingPkiScepServers) {
      return Promise.resolve(state.pkiScepServers)
    }
    if (!state.pkiScepServers) {
      commit('PKI_SCEPSERVERS_REQUEST')
      return api.getPkiScepServers().then(response => {
        const { data: { items = [] } = {} } = response
        commit('PKI_SCEPSERVERS_UPDATED', items || [])
        return state.pkiScepServers
      })
    } else {
      return Promise.resolve(state.pkiScepServers)
    }
  },
  resetPkiScepServers: ({ state, commit }) => {
    if (state.pkiScepServers) {
      commit('PKI_SCEPSERVERS_RESET')
    }
  },
  getPkiProviders: ({ state, getters, commit }) => {
    if (getters.isLoadingPkiProviders) {
      return Promise.resolve(state.pkiProviders)
    }
    if (!state.pkiProviders) {
      commit('PKI_PROVIDERS_REQUEST')
      return api.getPkiProviders().then(response => {
        commit('PKI_PROVIDERS_UPDATED', response.data.items)
        return state.pkiProviders
      })
    } else {
      return Promise.resolve(state.pkiProviders)
    }
  },
  getPortalModules: ({ state, getters, commit }) => {
    if (getters.isLoadingPortalModules) {
      return Promise.resolve(state.portalModules)
    }
    if (!state.portalModules) {
      commit('PORTAL_MODULES_REQUEST')
      return api.getPortalModules().then(response => {
        commit('PORTAL_MODULES_UPDATED', response.data.items)
        return state.portalModules
      })
    } else {
      return Promise.resolve(state.portalModules)
    }
  },
  getProvisionings: ({ state, getters, commit }) => {
    if (getters.isLoadingProvisionings) {
      return Promise.resolve(state.provisionings)
    }
    if (!state.provisionings) {
      commit('PROVISIONINGS_REQUEST')
      return api.getProvisionings().then(response => {
        commit('PROVISIONINGS_UPDATED', response.data.items)
        return state.provisionings
      })
    } else {
      return Promise.resolve(state.provisionings)
    }
  },
  getRadiusEaps: ({ state, getters, commit }) => {
    if (getters.isLoadingRadiusEaps) {
      return Promise.resolve(state.radiusEaps)
    }
    if (!state.radiusEaps) {
      commit('RADIUS_EAPS_REQUEST')
      return api.getRadiusEaps().then(response => {
        commit('RADIUS_EAPS_UPDATED', response.data.items)
        return state.radiusEaps
      })
    } else {
      return Promise.resolve(state.radiusEaps)
    }
  },
  getRadiusFasts: ({ state, getters, commit }) => {
    if (getters.isLoadingRadiusFasts) {
      return Promise.resolve(state.radiusFasts)
    }
    if (!state.radiusFasts) {
      commit('RADIUS_FASTS_REQUEST')
      return api.getRadiusFasts().then(response => {
        commit('RADIUS_FASTS_UPDATED', response.data.items)
        return state.radiusFasts
      })
    } else {
      return Promise.resolve(state.radiusFasts)
    }
  },
  getRadiusOcsps: ({ state, getters, commit }) => {
    if (getters.isLoadingRadiusOcsps) {
      return Promise.resolve(state.radiusOcsps)
    }
    if (!state.radiusOcsps) {
      commit('RADIUS_OCSPS_REQUEST')
      return api.getRadiusOcsps().then(response => {
        commit('RADIUS_OCSPS_UPDATED', response.data.items)
        return state.radiusOcsps
      })
    } else {
      return Promise.resolve(state.radiusOcsps)
    }
  },
  getRadiusSsls: ({ state, getters, commit }) => {
    if (getters.isLoadingRadiusSsls) {
      return Promise.resolve(state.radiusSsls)
    }
    if (!state.radiusSsls) {
      commit('RADIUS_SSLS_REQUEST')
      return api.getRadiusSsls().then(response => {
        commit('RADIUS_SSLS_UPDATED', response.data.items)
        return state.radiusSsls
      })
    } else {
      return Promise.resolve(state.radiusSsls)
    }
  },
  getRadiusTlss: ({ state, getters, commit }) => {
    if (getters.isLoadingRadiusTlss) {
      return Promise.resolve(state.radiusTlss)
    }
    if (!state.radiusTlss) {
      commit('RADIUS_TLSS_REQUEST')
      return api.getRadiusTlss().then(response => {
        commit('RADIUS_TLSS_UPDATED', response.data.items)
        return state.radiusTlss
      })
    } else {
      return Promise.resolve(state.radiusTlss)
    }
  },
  getRealms: ({ state, getters, commit }) => {
    if (getters.isLoadingRealms) {
      return Promise.resolve(state.realms)
    }
    if (!state.realms) {
      commit('REALMS_REQUEST')
      return api.getRealms().then(response => {
        commit('REALMS_UPDATED', response.data.items)
        return state.realms
      })
    } else {
      return Promise.resolve(state.realms)
    }
  },
  resetRealms: ({ state, commit }) => {
    if (state.realms) {
      commit('REALMS_RESET')
    }
  },
  getRoles: ({ state, getters, commit }) => {
    if (getters.isLoadingRoles) {
      return Promise.resolve(state.roles)
    }
    if (acl.$can('read', 'nodes')) {
      if (!state.roles) {
        commit('ROLES_REQUEST')
        return api.getRoles().then(response => {
          commit('ROLES_UPDATED', response.data.items)
          return state.roles
        })
      } else {
        return Promise.resolve(state.roles)
      }
    } else {
      commit('ROLES_UPDATED', [])
      return Promise.resolve(state.roles)
    }
  },
  getRoutedNetworks: ({ state, getters, commit }) => {
    if (getters.isLoadingRoutedNetworks) {
      return Promise.resolve(state.routedNetworks)
    }
    if (!state.routedNetworks) {
      commit('ROUTED_NETWORKS_REQUEST')
      return api.getRoutedNetworks().then(response => {
        commit('ROUTED_NETWORKS_UPDATED', response.data.items)
        return state.routedNetworks
      })
    } else {
      return Promise.resolve(state.routedNetworks)
    }
  },
  getScans: ({ state, getters, commit }) => {
    if (getters.isLoadingScans) {
      return Promise.resolve(state.scans)
    }
    if (!state.scans) {
      commit('SCANS_REQUEST')
      return api.getScans().then(response => {
        commit('SCANS_UPDATED', response.data.items)
        return state.scans
      })
    } else {
      return Promise.resolve(state.scans)
    }
  },
  getSecurityEvents: ({ commit, getters, state }) => {
    if (getters.isLoadingSecurityEvents) {
      return Promise.resolve(state.securityEvents)
    }
    if (acl.$can('read', 'security_events')) {
      if (!state.securityEvents) {
        commit('SECURITY_EVENTS_REQUEST')
        return api.getSecurityEvents().then(response => {
          commit('SECURITY_EVENTS_UPDATED', response.data.items)
          return state.securityEvents
        })
      }
    } else {
      commit('SECURITY_EVENTS_UPDATED', [])
      return state.securityEvents
    }
    return Promise.resolve(state.securityEvents)
  },
  getSources: ({ state, getters, commit }) => {
    if (getters.isLoadingSources) {
      return Promise.resolve(state.sources)
    }
    if (!state.sources) {
      commit('SOURCES_REQUEST')
      return api.getSources().then(response => {
        commit('SOURCES_UPDATED', response.data.items)
        return state.sources
      })
    } else {
      return Promise.resolve(state.sources)
    }
  },
  getSsids: ({ state, getters, commit }) => {
    if (getters.isLoadingSsids) {
      return Promise.resolve(state.ssids)
    }
    if (!state.ssids) {
      commit('SSIDS_REQUEST')
      return api.getSsids().then(response => {
        commit('SSIDS_UPDATED', response.data.items)
        return state.ssids
      })
    } else {
      return Promise.resolve(state.ssids)
    }
  },
  getSwitches: ({ state, getters, commit }) => {
    if (getters.isLoadingSwitches) {
      return Promise.resolve(state.switches)
    }
    if (acl.$can('read', 'switches')) {
      if (!state.switches) {
        commit('SWITCHES_REQUEST')
        return api.getSwitches().then(response => {
          // group can be undefined
          response.data.items.forEach(function (item, index) {
            response.data.items[index] = Object.assign({ group: item.group || 'default' }, item)
          })
          commit('SWITCHES_UPDATED', response.data.items)
          return state.switches
        })
      } else {
        return Promise.resolve(state.switches)
      }
    }
    else {
      commit('SWITCHES_UPDATED', [])
      return state.switches
    }
  },
  getSwitchGroups: ({ state, getters, commit }) => {
    if (getters.isLoadingSwitchGroups) {
      return Promise.resolve(state.switchGroups)
    }
    if (!state.switchGroups) {
      commit('SWITCH_GROUPS_REQUEST')
      return api.getSwitchGroups().then(response => {
        const { data: { items: switchGroups = [] } = {} } = response
        let promises = []
        switchGroups.map((switchGroup, index) => {
          const { id } = switchGroup
          promises.push(api.getSwitchGroupMembers(id).then(response => {
            const { data: { items: members = [] } = {} } = response
            switchGroups[index].members = members
          }))
        })
        return Promise.all(promises.map(p => p.catch(e => e))).then(() => {
          commit('SWITCH_GROUPS_UPDATED', switchGroups)
          return state.switchGroups
        }).catch(err => {
          commit('SWITCH_GROUPS_ERROR', err)
          throw err
        })
      }).catch((err) => {
        commit('SWITCH_GROUPS_ERROR', err)
        throw err
      })
    } else {
      return Promise.resolve(state.switchGroups)
    }
  },
  getSwitchTemplates: ({ state, getters, commit }) => {
    if (getters.isLoadingSwitchTemplates) {
      return Promise.resolve(state.switchTemplates)
    }
    if (!state.switchTemplates) {
      commit('SWITCH_TEMPLATES_REQUEST')
      return api.getSwitchTemplates().then(response => {
        commit('SWITCH_TEMPLATES_UPDATED', response.data.items)
        return state.switchTemplates
      }).catch((err) => {
        commit('SWITCH_TEMPLATES_ERROR', err)
        throw err
      })
    } else {
      return Promise.resolve(state.switchTemplates)
    }
  },
  getSyslogForwarders: ({ state, getters, commit }) => {
    if (getters.isLoadingSyslogForwarders) {
      return Promise.resolve(state.syslogForwarders)
    }
    if (!state.syslogForwarders) {
      commit('SYSLOG_FORWARDERS_REQUEST')
      return api.getSyslogForwarders().then(response => {
        commit('SYSLOG_FORWARDERS_UPDATED', response.data.items)
        return state.syslogForwarders
      })
    } else {
      return Promise.resolve(state.syslogForwarders)
    }
  },
  getEventHandlers: ({ state, getters, commit }) => {
    if (getters.isLoadingEventHandlers) {
      return Promise.resolve(state.eventHandlers)
    }
    if (!state.eventHandlers) {
      commit('EVENT_HANDLERS_REQUEST')
      return api.getEventHandlers().then(response => {
        commit('EVENT_HANDLERS_UPDATED', response.data.items)
        return state.eventHandlers
      })
    } else {
      return Promise.resolve(state.eventHandlers)
    }
  },
  getWrixLocations: ({ commit, getters, state }) => {
    if (getters.isLoadingWrixLocations) {
      return Promise.resolve(state.wrixLocations)
    }
    if (!state.wrixLocations) {
      commit('WRIX_LOCATIONS_REQUEST')
      return api.getWrixLocations().then(response => {
        commit('WRIX_LOCATIONS_UPDATED', response.data.items)
        return state.wrixLocations
      })
    } else {
      return Promise.resolve(state.wrixLocations)
    }
  },
  stringifyCondition: (_, json) => {
    return api.flattenCondition({ condition: json }).then(response => {
      const { item: { condition_string } = {} } = response
      return condition_string
    }).catch(err => {
      throw err
    })
  },
  parseCondition: (_, string) => {
    return api.parseCondition({ condition: string }).then(response => {
      const { item: { condition } = {} } = response
      return condition
    }).catch(err => {
      throw err
    })
  }
}

const mutations = {
  ADMIN_ROLES_REQUEST: (state) => {
    state.adminRolesStatus = types.LOADING
  },
  ADMIN_ROLES_UPDATED: (state, adminRoles) => {
    state.adminRoles = adminRoles
    state.adminRolesStatus = types.SUCCESS
  },
  BASE_ACTIVE_ACTIVE_REQUEST: (state) => {
    state.baseActiveActiveStatus = types.LOADING
  },
  BASE_ACTIVE_ACTIVE_UPDATED: (state, baseActiveActive) => {
    state.baseActiveActive = baseActiveActive
    state.baseActiveActiveStatus = types.SUCCESS
  },
  BASE_FLEETDM_REQUEST: (state) => {
    state.baseFleetDMStatus = types.LOADING
  },
  BASE_FLEETDM_UPDATED: (state, baseFleetDM) => {
    state.baseFleetDM = baseFleetDM
    state.baseFleetDMStatus = types.SUCCESS
  },
  BASE_ADVANCED_REQUEST: (state) => {
    state.baseAdvancedStatus = types.LOADING
  },
  BASE_ADVANCED_UPDATED: (state, baseAdvanced) => {
    state.baseAdvanced = baseAdvanced
    state.baseAdvancedStatus = types.SUCCESS
  },
  BASE_ALERTING_REQUEST: (state) => {
    state.baseAlertingStatus = types.LOADING
  },
  BASE_ALERTING_UPDATED: (state, baseAlerting) => {
    state.baseAlerting = baseAlerting
    state.baseAlertingStatus = types.SUCCESS
  },
  BASE_CAPTIVE_PORTAL_REQUEST: (state) => {
    state.baseCaptivePortalStatus = types.LOADING
  },
  BASE_CAPTIVE_PORTAL_UPDATED: (state, baseCaptivePortal) => {
    state.baseCaptivePortal = baseCaptivePortal
    state.baseCaptivePortalStatus = types.SUCCESS
  },
  BASE_DATABASE_REQUEST: (state) => {
    state.baseDatabaseStatus = types.LOADING
  },
  BASE_DATABASE_UPDATED: (state, baseDatabase) => {
    state.baseDatabase = baseDatabase
    state.baseDatabaseStatus = types.SUCCESS
  },
  BASE_DATABASE_ADVANCED_REQUEST: (state) => {
    state.baseDatabaseAdvancedStatus = types.LOADING
  },
  BASE_DATABASE_ADVANCED_UPDATED: (state, baseDatabaseAdvanced) => {
    state.baseDatabaseAdvanced = baseDatabaseAdvanced
    state.baseDatabaseAdvancedStatus = types.SUCCESS
  },
  BASE_DATABASE_ENCRYPTION_REQUEST: (state) => {
    state.baseDatabaseEncryptionStatus = types.LOADING
  },
  BASE_DATABASE_ENCRYPTION_UPDATED: (state, baseDatabaseEncryption) => {
    state.baseDatabaseEncryption = baseDatabaseEncryption
    state.baseDatabaseEncryptionStatus = types.SUCCESS
  },
  BASE_FENCING_REQUEST: (state) => {
    state.baseFencingStatus = types.LOADING
  },
  BASE_FENCING_UPDATED: (state, baseFencing) => {
    state.baseFencing = baseFencing
    state.baseFencingStatus = types.SUCCESS
  },
  BASE_FINGERBANK_DEVICE_CHANGE_REQUEST: (state) => {
    state.baseFingerbankDeviceChangeStatus = types.LOADING
  },
  BASE_FINGERBANK_DEVICE_CHANGE_UPDATED: (state, baseFingerbankDeviceChange) => {
    state.baseFingerbankDeviceChange = baseFingerbankDeviceChange
    state.baseFingerbankDeviceChangeStatus = types.SUCCESS
  },
  BASE_GENERAL_REQUEST: (state) => {
    state.baseGeneralStatus = types.LOADING
  },
  BASE_GENERAL_UPDATED: (state, baseGeneral) => {
    state.baseGeneral = baseGeneral
    state.baseGeneralStatus = types.SUCCESS
  },
  BASE_GUESTS_ADMIN_REGISTRATION_REQUEST: (state) => {
    state.baseGuestsAdminRegistrationStatus = types.LOADING
  },
  BASE_GUESTS_ADMIN_REGISTRATION_UPDATED: (state, baseGuestsAdminRegistration) => {
    state.baseGuestsAdminRegistration = baseGuestsAdminRegistration
    state.baseGuestsAdminRegistrationStatus = types.SUCCESS
  },
  BASE_GUESTS_ADMIN_REGISTRATION_DELETED: (state) => {
    state.baseGuestsAdminRegistration = false
  },
  BASE_INLINE_REQUEST: (state) => {
    state.baseInlineStatus = types.LOADING
  },
  BASE_INLINE_UPDATED: (state, baseInline) => {
    state.baseInline = baseInline
    state.baseInlineStatus = types.SUCCESS
  },
  BASE_MSE_TAB_REQUEST: (state) => {
    state.baseMseTabStatus = types.LOADING
  },
  BASE_MSE_TAB_UPDATED: (state, baseMseTab) => {
    state.baseMseTab = baseMseTab
    state.baseMseTabStatus = types.SUCCESS
  },
  BASE_NETWORK_REQUEST: (state) => {
    state.baseNetworkStatus = types.LOADING
  },
  BASE_NETWORK_UPDATED: (state, baseNetwork) => {
    state.baseNetwork = baseNetwork
    state.baseNetworkStatus = types.SUCCESS
  },
  BASE_NODE_IMPORT_REQUEST: (state) => {
    state.baseNodeImportStatus = types.LOADING
  },
  BASE_NODE_IMPORT_UPDATED: (state, baseNodeImport) => {
    state.baseNodeImport = baseNodeImport
    state.baseNodeImportStatus = types.SUCCESS
  },
  BASE_PARKING_REQUEST: (state) => {
    state.baseParkingStatus = types.LOADING
  },
  BASE_PARKING_UPDATED: (state, baseParking) => {
    state.baseParking = baseParking
    state.baseParkingStatus = types.SUCCESS
  },
  BASE_PFDHCP_REQUEST: (state) => {
    state.basePFDHCPStatus = types.LOADING
  },
  BASE_PFDHCP_UPDATED: (state, basePFDHCP) => {
    state.basePFDHCP = basePFDHCP
    state.basePFDHCPStatus = types.SUCCESS
  },
  BASE_PORTS_REQUEST: (state) => {
    state.basePortsStatus = types.LOADING
  },
  BASE_PORTS_UPDATED: (state, basePorts) => {
    state.basePorts = basePorts
    state.basePortsStatus = types.SUCCESS
  },
  BASE_PROVISIONING_REQUEST: (state) => {
    state.baseProvisioningStatus = types.LOADING
  },
  BASE_PROVISIONING_UPDATED: (state, baseProvisioning) => {
    state.baseProvisioning = baseProvisioning
    state.baseProvisioningStatus = types.SUCCESS
  },
  BASE_RADIUS_CONFIGURATION_REQUEST: (state) => {
    state.baseRadiusConfigurationStatus = types.LOADING
  },
  BASE_RADIUS_CONFIGURATION_UPDATED: (state, baseRadiusConfiguration) => {
    state.baseRadiusConfiguration = baseRadiusConfiguration
    state.baseRadiusConfigurationStatus = types.SUCCESS
  },
  BASE_DNS_CONFIGURATION_REQUEST: (state) => {
    state.baseDnsConfigurationStatus = types.LOADING
  },
  BASE_DNS_CONFIGURATION_UPDATED: (state, baseDnsConfiguration) => {
    state.baseDnsConfiguration = baseDnsConfiguration
    state.baseDnsConfigurationStatus = types.SUCCESS
  },
  BASE_SERVICES_REQUEST: (state) => {
    state.baseServicesStatus = types.LOADING
  },
  BASE_SERVICES_UPDATED: (state, baseServices) => {
    state.baseServices = baseServices
    state.baseServicesStatus = types.SUCCESS
  },
  BASE_SNMP_TRAPS_REQUEST: (state) => {
    state.baseSNMPTrapsStatus = types.LOADING
  },
  BASE_SNMP_TRAPS_UPDATED: (state, baseSNMPTraps) => {
    state.baseSNMPTraps = baseSNMPTraps
    state.baseSNMPTrapsStatus = types.SUCCESS
  },
  BASE_WEBSERVICES_REQUEST: (state) => {
    state.baseWebServicesStatus = types.LOADING
  },
  BASE_WEBSERVICES_UPDATED: (state, baseWebServices) => {
    state.baseWebServices = baseWebServices
    state.baseWebServicesStatus = types.SUCCESS
  },
  BILLING_TIERS_REQUEST: (state) => {
    state.billingTiersStatus = types.LOADING
  },
  BILLING_TIERS_UPDATED: (state, billingTiers) => {
    state.billingTiers = billingTiers
    state.billingTiersStatus = types.SUCCESS
  },
  CLOUDS_REQUEST: (state) => {
    state.cloudsStatus = types.LOADING
  },
  CLOUDS_UPDATED: (state, clouds) => {
    state.clouds = clouds
    state.cloudsStatus = types.SUCCESS
  },
  CONNECTION_PROFILES_REQUEST: (state) => {
    state.connectionProfilesStatus = types.LOADING
  },
  CONNECTION_PROFILES_UPDATED: (state, connectionProfiles) => {
    state.connectionProfiles = connectionProfiles
    state.connectionProfilesStatus = types.SUCCESS
  },
  CONNECTORS_REQUEST: (state) => {
    state.connectorsStatus = types.LOADING
  },
  CONNECTORS_UPDATED: (state, connectors) => {
    state.connectors = connectors
    state.connectorsStatus = types.SUCCESS
  },
  DOMAINS_REQUEST: (state) => {
    state.domainsStatus = types.LOADING
  },
  DOMAINS_UPDATED: (state, domains) => {
    state.domains = domains
    state.domainsStatus = types.SUCCESS
  },
  EVENT_LOGGERS_REQUEST: (state) => {
    state.eventLoggersStatus = types.LOADING
  },
  EVENT_LOGGERS_UPDATED: (state, eventLoggers) => {
    state.eventLoggers = eventLoggers
    state.eventLoggersStatus = types.SUCCESS
  },
  FILTER_ENGINES_REQUEST: (state) => {
    state.filterEnginesStatus = types.LOADING
  },
  FILTER_ENGINES_UPDATED: (state, { collection, filterEngines}) => {
    if (!state.filterEngines) {
      state.filterEngines = {}
    }
    state.filterEngines[collection] = filterEngines
    state.filterEnginesStatus = types.SUCCESS
  },
  FILTER_ENGINES_DELETED: (state) => {
    state.filterEngines = false
  },
  FIREWALLS_REQUEST: (state) => {
    state.firewallsStatus = types.LOADING
  },
  FIREWALLS_UPDATED: (state, firewalls) => {
    state.firewalls = firewalls
    state.firewallsStatus = types.SUCCESS
  },
  FLOATING_DEVICES_REQUEST: (state) => {
    state.floatingDevicesStatus = types.LOADING
  },
  FLOATING_DEVICES_UPDATED: (state, floatingDevices) => {
    state.floatingDevices = floatingDevices
    state.floatingDevicesStatus = types.SUCCESS
  },
  INTERFACES_REQUEST: (state) => {
    state.interfacesStatus = types.LOADING
  },
  INTERFACES_UPDATED: (state, interfaces) => {
    state.interfaces = interfaces
    state.interfacesStatus = types.SUCCESS
  },
  LAYER2_NETWORKS_REQUEST: (state) => {
    state.layer2NetworksStatus = types.LOADING
  },
  LAYER2_NETWORKS_UPDATED: (state, layer2Networks) => {
    state.layer2Networks = layer2Networks
    state.layer2NetworksStatus = types.SUCCESS
  },
  MAINTENANCE_TASKS_REQUEST: (state) => {
    state.maintenanceTasksStatus = types.LOADING
  },
  MAINTENANCE_TASKS_UPDATED: (state, maintenanceTasks) => {
    state.maintenanceTasks = maintenanceTasks
    state.maintenanceTasksStatus = types.SUCCESS
  },
  MFAS_REQUEST: (state) => {
    state.mfasStatus = types.LOADING
  },
  MFAS_UPDATED: (state, mfas) => {
    state.mfas = mfas
    state.mfasStatus = types.SUCCESS
  },
  NETWORK_BEHAVIOR_POLICIES_REQUEST: (state) => {
    state.networkBehaviorPoliciesStatus = types.LOADING
  },
  NETWORK_BEHAVIOR_POLICIES_UPDATED: (state, networkBehaviorPolicies) => {
    state.networkBehaviorPolicies
      = networkBehaviorPolicies
    state.networkBehaviorPoliciesStatus = types.SUCCESS
  },
  PKI_CAS_REQUEST: (state) => {
    state.pkiCasStatus = types.LOADING
  },
  PKI_CAS_UPDATED: (state, pkiCas) => {
    state.pkiCas = pkiCas
    state.pkiCasStatus = types.SUCCESS
  },
  PKI_CAS_RESET: (state) => {
    state.pkiCas = false
  },
  PKI_PROFILES_REQUEST: (state) => {
    state.pkiProfilesStatus = types.LOADING
  },
  PKI_PROFILES_UPDATED: (state, pkiProfiles) => {
    state.pkiProfiles = pkiProfiles
    state.pkiProfilesStatus = types.SUCCESS
  },
  PKI_PROFILES_RESET: (state) => {
    state.pkiProfiles = false
  },
  PKI_CERTS_REQUEST: (state) => {
    state.pkiCertsStatus = types.LOADING
  },
  PKI_CERTS_UPDATED: (state, pkiCerts) => {
    state.pkiCerts = pkiCerts
    state.pkiCertsStatus = types.SUCCESS
  },
  PKI_CERTS_RESET: (state) => {
    state.pkiCerts = false
  },
  PKI_SCEPSERVERS_REQUEST: (state) => {
    state.pkiScepServersStatus = types.LOADING
  },
  PKI_SCEPSERVERS_UPDATED: (state, pkiCerts) => {
    state.pkiScepServers = pkiCerts
    state.pkiScepServersStatus = types.SUCCESS
  },
  PKI_SCEPSERVERS_RESET: (state) => {
    state.pkiScepServers = false
  },
  PKI_PROVIDERS_REQUEST: (state) => {
    state.pkiProvidersStatus = types.LOADING
  },
  PKI_PROVIDERS_UPDATED: (state, pkiProviders) => {
    state.pkiProviders = pkiProviders
    state.pkiProvidersStatus = types.SUCCESS
  },
  PORTAL_MODULES_REQUEST: (state) => {
    state.portalModulesStatus = types.LOADING
  },
  PORTAL_MODULES_UPDATED: (state, portalModules) => {
    state.portalModules = portalModules
    state.portalModulesStatus = types.SUCCESS
  },
  PROVISIONINGS_REQUEST: (state) => {
    state.provisioningsStatus = types.LOADING
  },
  PROVISIONINGS_UPDATED: (state, provisionings) => {
    state.provisionings = provisionings
    state.provisioningsStatus = types.SUCCESS
  },
  RADIUS_EAPS_REQUEST: (state) => {
    state.radiusEapsStatus = types.LOADING
  },
  RADIUS_EAPS_UPDATED: (state, eaps) => {
    state.radiusEaps = eaps
    state.radiusEapsStatus = types.SUCCESS
  },
  RADIUS_FASTS_REQUEST: (state) => {
    state.radiusFastsStatus = types.LOADING
  },
  RADIUS_FASTS_UPDATED: (state, eaps) => {
    state.radiusFasts = eaps
    state.radiusFastsStatus = types.SUCCESS
  },
  RADIUS_OCSPS_REQUEST: (state) => {
    state.radiusOcspsStatus = types.LOADING
  },
  RADIUS_OCSPS_UPDATED: (state, eaps) => {
    state.radiusOcsps = eaps
    state.radiusOcspsStatus = types.SUCCESS
  },
  RADIUS_SSLS_REQUEST: (state) => {
    state.radiusSslsStatus = types.LOADING
  },
  RADIUS_SSLS_UPDATED: (state, eaps) => {
    state.radiusSsls = eaps
    state.radiusSslsStatus = types.SUCCESS
  },
  RADIUS_TLSS_REQUEST: (state) => {
    state.radiusTlssStatus = types.LOADING
  },
  RADIUS_TLSS_UPDATED: (state, eaps) => {
    state.radiusTlss = eaps
    state.radiusTlssStatus = types.SUCCESS
  },
  REALMS_REQUEST: (state) => {
    if (!state.realms)
      Vue.set(state, 'realms', [])
    state.realmsStatus = types.LOADING
  },
  REALMS_UPDATED: (state, items) => {
    Vue.set(state, 'realms', items)
    state.realmsStatus = types.SUCCESS
  },
  REALMS_RESET: (state) => {
    state.realms = {}
  },
  ROLES_REQUEST: (state) => {
    state.rolesStatus = types.LOADING
  },
  ROLES_UPDATED: (state, roles) => {
    state.roles = roles
    state.rolesStatus = types.SUCCESS
  },
  ROUTED_NETWORKS_REQUEST: (state) => {
    state.routedNetworksStatus = types.LOADING
  },
  ROUTED_NETWORKS_UPDATED: (state, routedNetworks) => {
    state.routedNetworks = routedNetworks
    state.routedNetworksStatus = types.SUCCESS
  },
  SCANS_REQUEST: (state) => {
    state.scansStatus = types.LOADING
  },
  SCANS_UPDATED: (state, scans) => {
    state.scans = scans
    state.scansStatus = types.SUCCESS
  },
  SECURITY_EVENTS_REQUEST: (state) => {
    state.securityEventsStatus = types.LOADING
  },
  SECURITY_EVENTS_UPDATED: (state, securityEvents) => {
    let ref = {}
    for (let securityEvent of securityEvents) {
      ref[securityEvent.id] = Object.assign({}, securityEvent)
    }
    state.securityEvents = ref
    state.securityEventsStatus = types.SUCCESS
  },
  SELF_SERVICES_REQUEST: (state) => {
    state.selfServicesStatus = types.LOADING
  },
  SELF_SERVICES_UPDATED: (state, selfServices) => {
    state.selfServices = selfServices
    state.selfServicesStatus = types.SUCCESS
  },
  SOURCES_REQUEST: (state) => {
    state.sourcesStatus = types.LOADING
  },
  SOURCES_UPDATED: (state, sources) => {
    state.sources = sources
    state.sourcesStatus = types.SUCCESS
  },
  SSIDS_REQUEST: (state) => {
    state.ssidsStatus = types.LOADING
  },
  SSIDS_UPDATED: (state, ssids) => {
    state.ssids = ssids
    state.ssidsStatus = types.SUCCESS
  },
  SWITCHES_REQUEST: (state) => {
    state.switchesStatus = types.LOADING
  },
  SWITCHES_UPDATED: (state, switches) => {
    state.switches = switches
    state.switchesStatus = types.SUCCESS
  },
  SWITCH_GROUPS_REQUEST: (state) => {
    state.switchGroupsStatus = types.LOADING
  },
  SWITCH_GROUPS_UPDATED: (state, switchGroups) => {
    state.switchGroups = switchGroups
    state.switchGroupsStatus = types.SUCCESS
  },
  SWITCH_GROUPS_ERROR: (state) => {
    state.switchGroupsStatus = types.ERROR
  },
  SWITCH_TEMPLATES_REQUEST: (state) => {
    state.switchTemplatesStatus = types.LOADING
  },
  SWITCH_TEMPLATES_UPDATED: (state, switchTemplates) => {
    state.switchTemplates = switchTemplates
    state.switchTemplatesStatus = types.SUCCESS
  },
  SWITCH_TEMPLATES_ERROR: (state) => {
    state.switchTemplatesStatus = types.ERROR
  },
  SYSLOG_FORWARDERS_REQUEST: (state) => {
    state.syslogForwardersStatus = types.LOADING
  },
  SYSLOG_FORWARDERS_UPDATED: (state, syslogForwarders) => {
    state.syslogForwarders = syslogForwarders
    state.syslogForwardersStatus = types.SUCCESS
  },
  EVENT_HANDLERS_REQUEST: (state) => {
    state.eventHandlersStatus = types.LOADING
  },
  EVENT_HANDLERS_UPDATED: (state, eventHandlers) => {
    state.eventHandlers = eventHandlers
    state.eventHandlersStatus = types.SUCCESS
  },
  WRIX_LOCATIONS_REQUEST: (state) => {
    state.wrixLocationsStatus = types.LOADING
  },
  WRIX_LOCATIONS_UPDATED: (state, wrixLocations) => {
    state.wrixLocations = wrixLocations
    state.wrixLocationsStatus = types.SUCCESS
  },
  $RESET: (state) => {
    // eslint-disable-next-line no-unused-vars
    state = initialState()
  }
}

export default {
  namespaced: true,
  state: initialState(),
  getters,
  actions,
  mutations
}
