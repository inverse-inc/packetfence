import apiCall from '@/utils/api'

export default {

  /**
   * Admin Roles
   */
  adminRoles: params => {
    return apiCall.get('config/admin_roles', { params }).then(response => {
      return response.data
    })
  },
  adminRolesOptions: () => {
    return apiCall.options('config/admin_roles').then(response => {
      return response.data
    })
  },
  adminRole: id => {
    return apiCall.get(['config', 'admin_role', id]).then(response => {
      return response.data.item
    })
  },
  adminRoleOptions: id => {
    return apiCall.options(['config', 'admin_role', id]).then(response => {
      return response.data
    })
  },
  createAdminRole: data => {
    return apiCall.post('config/admin_roles', data).then(response => {
      return response.data
    })
  },
  updateAdminRole: data => {
    return apiCall.patch(['config', 'admin_role', data.id], data).then(response => {
      return response.data
    })
  },
  deleteAdminRole: id => {
    return apiCall.delete(['config', 'admin_role', id])
  },

  /**
   * Authentication Sources
   */
  authenticationSources: params => {
    return apiCall.get('config/sources', { params }).then(response => {
      return response.data
    })
  },
  authenticationSourcesOptions: sourceType => {
    return apiCall.options(['config', 'sources'], { params: { type: sourceType } }).then(response => {
      return response.data
    })
  },
  authenticationSource: id => {
    return apiCall.get(['config', 'source', id]).then(response => {
      return response.data.item
    })
  },
  authenticationSourceOptions: id => {
    return apiCall.options(['config', 'source', id]).then(response => {
      return response.data
    })
  },
  authenticationSourceSAMLMetaData: id => {
    return apiCall.get(['config', 'source', id, 'saml_metadata']).then(response => {
      return response.data
    })
  },
  createAuthenticationSource: data => {
    return apiCall.post('config/sources', data).then(response => {
      return response.data
    })
  },
  updateAuthenticationSource: data => {
    return apiCall.patch(['config', 'source', data.id], data).then(response => {
      return response.data
    })
  },
  deleteAuthenticationSource: id => {
    return apiCall.delete(['config', 'source', id])
  },
  sortAuthenticationSources: data => {
    return apiCall.patch('config/sources/sort_items', data).then(response => {
      return response
    })
  },
  testAuthenticationSource: data => {
    return apiCall.postQuiet('config/sources/test', data).then(response => {
      return response
    })
  },

  /**
   * Bases
   */
  bases: params => {
    return apiCall.get('config/bases', { params }).then(response => {
      return response.data
    })
  },
  base: id => {
    return apiCall.get(['config', 'base', id]).then(response => {
      return response.data.item
    })
  },
  baseOptions: id => {
    return apiCall.options(['config', 'base', id]).then(response => {
      return response.data
    })
  },
  updateBase: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'base', data.id], data).then(response => {
      return response.data
    })
  },
  secureDatabase: data => {
    return apiCall.postQuiet('config/base/database/secure_installation', data)
  },
  createDatabase: data => {
    return apiCall.postQuiet('config/base/database/create', data)
  },
  assignDatabase: data => {
    return apiCall.postQuiet('config/base/database/assign', data)
  },
  testDatabase: data => {
    return apiCall.postQuiet('config/base/database/test', data)
  },
  testSmtp: data => {
    const post = data.quiet ? 'postQuiet' : 'post'
    return apiCall[post](['config', 'bases', 'test_smtp'], data).then(response => {
      return response.data
    })
  },

  /**
   * Billing Tiers
   */
  billingTiers: params => {
    return apiCall.get('config/billing_tiers', { params }).then(response => {
      return response.data
    })
  },
  billingTiersOptions: () => {
    return apiCall.options('config/billing_tiers').then(response => {
      return response.data
    })
  },
  billingTier: id => {
    return apiCall.get(['config', 'billing_tier', id]).then(response => {
      return response.data.item
    })
  },
  billingTierOptions: id => {
    return apiCall.options(['config', 'billing_tier', id]).then(response => {
      return response.data
    })
  },
  createBillingTier: data => {
    return apiCall.post('config/billing_tiers', data).then(response => {
      return response.data
    })
  },
  updateBillingTier: data => {
    return apiCall.patch(['config', 'billing_tier', data.id], data).then(response => {
      return response.data
    })
  },
  deleteBillingTier: id => {
    return apiCall.delete(['config', 'billing_tier', id])
  },

  /**
   * Connection Profiles
   */
  connectionProfiles: params => {
    return apiCall.get(['config', 'connection_profiles'], { params }).then(response => {
      return response.data
    })
  },
  connectionProfilesOptions: () => {
    return apiCall.options('config/connection_profiles').then(response => {
      return response.data
    })
  },
  connectionProfile: id => {
    return apiCall.get(['config', 'connection_profile', id]).then(response => {
      return response.data.item
    })
  },
  connectionProfileOptions: id => {
    return apiCall.options(['config', 'connection_profile', id]).then(response => {
      return response.data
    })
  },
  createConnectionProfile: data => {
    return apiCall.post('config/connection_profiles', data).then(response => {
      return response.data
    })
  },
  updateConnectionProfile: data => {
    return apiCall.patch(['config', 'connection_profile', data.id], data).then(response => {
      return response.data
    })
  },
  deleteConnectionProfile: id => {
    return apiCall.delete(['config', 'connection_profile', id])
  },
  sortConnectionProfiles: data => {
    return apiCall.patch('config/connection_profiles/sort_items', data).then(response => {
      return response
    })
  },

  /**
   * Connection Profiles Files
   */
  connectionProfileFiles: params => {
    return apiCall.get(['config', 'connection_profile', params.id, 'files'], { params }).then(response => {
      return response.data
    })
  },
  connectionProfileFile: params => {
    const get = params.quiet ? 'getQuiet' : 'get'
    return apiCall[get](['config', 'connection_profile', params.id, 'files', ...params.filename.split('/')]).then(response => {
      return response.data
    })
  },
  createConnectionProfileFile: params => {
    return apiCall.put(['config', 'connection_profile', params.id, 'files', ...params.filename.split('/')], params.content).then(response => {
      return response.data
    })
  },
  updateConnectionProfileFile: params => {
    return apiCall.patch(['config', 'connection_profile', params.id, 'files', ...params.filename.split('/')], params.content).then(response => {
      return response.data
    })
  },
  deleteConnectionProfileFile: params => {
    return apiCall.delete(['config', 'connection_profile', params.id, 'files', ...params.filename.split('/')])
  },

  /**
   * Self Service
   */
  selfServices: params => {
    return apiCall.get('config/self_services', { params }).then(response => {
      return response.data
    })
  },
  selfServicesOptions: () => {
    return apiCall.options('config/self_services').then(response => {
      return response.data
    })
  },
  selfService: id => {
    return apiCall.get(['config', 'self_service', id]).then(response => {
      return response.data.item
    })
  },
  selfServiceOptions: id => {
    return apiCall.options(['config', 'self_service', id]).then(response => {
      return response.data
    })
  },
  createSelfService: data => {
    return apiCall.post('config/self_services', data).then(response => {
      return response.data
    })
  },
  updateSelfService: data => {
    return apiCall.patch(['config', 'self_service', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSelfService: id => {
    return apiCall.delete(['config', 'self_service', id])
  },

  /**
   * Domains
   */
  domains: params => {
    return apiCall.get('config/domains', { params }).then(response => {
      return response.data
    })
  },
  domainsOptions: () => {
    return apiCall.options('config/domains').then(response => {
      return response.data
    })
  },
  domain: id => {
    return apiCall.get(['config', 'domain', id]).then(response => {
      return response.data.item
    })
  },
  domainOptions: id => {
    return apiCall.options(['config', 'domain', id]).then(response => {
      return response.data
    })
  },
  createDomain: data => {
    return apiCall.post('config/domains', data).then(response => {
      return response.data
    })
  },
  updateDomain: data => {
    return apiCall.patch(['config', 'domain', data.id], data).then(response => {
      return response.data
    })
  },
  deleteDomain: id => {
    return apiCall.delete(['config', 'domain', id])
  },
  testDomain: id => {
    return apiCall.getQuiet(['config', 'domain', id, 'test_join']).then(response => {
      return response.data
    }).catch(err => {
      throw err
    })
  },
  joinDomain: data => {
    return apiCall.post(['config', 'domain', data.id, 'join'], data).then(response => {
      return response.data
    })
  },
  rejoinDomain: data => {
    return apiCall.post(['config', 'domain', data.id, 'rejoin'], data).then(response => {
      return response.data
    })
  },
  unjoinDomain: data => {
    return apiCall.post(['config', 'domain', data.id, 'unjoin'], data).then(response => {
      return response.data
    })
  },

  /**
   * Filters
   */
  filters: params => {
    return apiCall.get('config/filters', { params }).then(response => {
      return response.data
    })
  },
  filter: id => {
    return apiCall.get(['config', 'filter', id]).then(response => {
      return response.data
    })
  },
  updateFilter: (id, filter) => {
    return apiCall.put(['config', 'filter', id], filter).then(response => {
      return response.data
    })
  },

  /**
   * Filter Engines
   */
  filterEnginesCollections: params => {
    return apiCall.get('config/filter_engines', { params }).then(response => {
      return response.data
    })
  },
  filterEnginesCollection: collection => {
    return apiCall.get(['config', 'filter_engines', collection], { params: { limit: 1000 } }).then(response => {
      return response.data
    }).catch(err => {
      throw err
    })
  },
  filterEngine: ({ resource, id }) => {
    return apiCall.get(['config', 'filter_engines', resource, id]).then(response => {
      return response.data.item
    }).catch(err => {
      throw err
    })
  },
  filterEnginesOptions: collection => {
    return apiCall.options(['config', 'filter_engines', collection]).then(response => {
      return response.data
    })
  },
  filterEngineOptions: ({ resource, id }) => {
    return apiCall.options(['config', 'filter_engines', resource, id]).then(response => {
      return response.data
    })
  },
  sortFilterEngines: ({ collection, params }) => {
    const patch = params.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'filter_engines', collection, 'sort_items'], params).then(response => {
      return response.data
    })
  },
  createFilterEngine: ({ collection, data }) => {
    return apiCall.post(['config', 'filter_engines', collection], data).then(response => {
      return response.data
    })
  },
  updateFilterEngine: ({ resource, id, data }) => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'filter_engines', resource, id], data).then(response => {
      return response.data
    })
  },
  deleteFilterEngine: ({ resource, id }) => {
    return apiCall.delete(['config', 'filter_engines', resource, id])
  },

  /**
   * Fingerbank Profiling
   */
  fingerbankAccountInfo: () => {
    return apiCall.getQuiet(['fingerbank', 'account_info']).then(response => {
      return response.data
    })
  },
  fingerbankCanUseNbaEndpoints: () => {
    return apiCall.getQuiet(['fingerbank', 'can_use_nba_endpoints']).then(response => {
      return response.data
    })
  },
  fingerbankGeneralSettings: params => {
    return apiCall.get(['config', 'fingerbank_settings'], { params }).then(response => {
      return response.data.items
    })
  },
  fingerbankGeneralSettingsOptions: () => {
    return apiCall.options('config/fingerbank_settings').then(response => {
      return response.data
    })
  },
  fingerbankUpdateGeneralSetting: (id, params) => {
    const patch = params.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'fingerbank_setting', id], params).then(response => {
      return response.data
    })
  },
  fingerbankCombinations: params => {
    return apiCall.get(['fingerbank', 'local', 'combinations'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchCombinations: body => {
    return apiCall.post('fingerbank/local/combinations/search', body).then(response => {
      return response.data
    })
  },
  fingerbankCombination: id => {
    return apiCall.get(['fingerbank', 'local', 'combination', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateCombination: data => {
    return apiCall.post('fingerbank/local/combinations', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateCombination: data => {
    Object.keys(data).forEach(key => {
      if (/^not_/.test(key)) { // remove fields starting with 'not_'
        delete data[key]
      }
    })
    return apiCall.patch(['fingerbank', 'local', 'combination', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteCombination: id => {
    return apiCall.delete(['fingerbank', 'local', 'combination', id])
  },
  fingerbankDevices: params => {
    return apiCall.get(['fingerbank', 'all', 'devices'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchDevices: body => {
    return apiCall.post('fingerbank/all/devices/search', body).then(response => {
      return response.data
    })
  },
  fingerbankDevice: id => {
    return apiCall.get(['fingerbank', 'all', 'device', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateDevice: data => {
    return apiCall.post('fingerbank/local/devices', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateDevice: data => {
    return apiCall.patch(['fingerbank', 'local', 'device', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteDevice: id => {
    return apiCall.delete(['fingerbank', 'local', 'device', id])
  },
  fingerbankDhcpFingerprints: params => {
    return apiCall.get(['fingerbank', 'all', 'dhcp_fingerprints'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchDhcpFingerprints: body => {
    return apiCall.post('fingerbank/all/dhcp_fingerprints/search', body).then(response => {
      return response.data
    })
  },
  fingerbankDhcpFingerprint: id => {
    return apiCall.get(['fingerbank', 'all', 'dhcp_fingerprint', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateDhcpFingerprint: data => {
    return apiCall.post('fingerbank/local/dhcp_fingerprints', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateDhcpFingerprint: data => {
    return apiCall.patch(['fingerbank', 'local', 'dhcp_fingerprint', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteDhcpFingerprint: id => {
    return apiCall.delete(['fingerbank', 'local', 'dhcp_fingerprint', id])
  },
  fingerbankDhcpVendors: params => {
    return apiCall.get(['fingerbank', 'all', 'dhcp_vendors'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchDhcpVendors: body => {
    return apiCall.post('fingerbank/all/dhcp_vendors/search', body).then(response => {
      return response.data
    })
  },
  fingerbankDhcpVendor: id => {
    return apiCall.get(['fingerbank', 'all', 'dhcp_vendor', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateDhcpVendor: data => {
    return apiCall.post('fingerbank/local/dhcp_vendors', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateDhcpVendor: data => {
    return apiCall.patch(['fingerbank', 'local', 'dhcp_vendor', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteDhcpVendor: id => {
    return apiCall.delete(['fingerbank', 'local', 'dhcp_vendor', id])
  },
  fingerbankDhcpv6Fingerprints: params => {
    return apiCall.get(['fingerbank', 'all', 'dhcp6_fingerprints'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchDhcpv6Fingerprints: body => {
    return apiCall.post('fingerbank/all/dhcp6_fingerprints/search', body).then(response => {
      return response.data
    })
  },
  fingerbankDhcpv6Fingerprint: id => {
    return apiCall.get(['fingerbank', 'all', 'dhcp6_fingerprint', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateDhcpv6Fingerprint: data => {
    return apiCall.post('fingerbank/local/dhcp6_fingerprints', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateDhcpv6Fingerprint: data => {
    return apiCall.patch(['fingerbank', 'local', 'dhcp6_fingerprint', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteDhcpv6Fingerprint: id => {
    return apiCall.delete(['fingerbank', 'local', 'dhcp6_fingerprint', id])
  },
  fingerbankDhcpv6Enterprises: params => {
    return apiCall.get(['fingerbank', 'all', 'dhcp6_enterprises'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchDhcpv6Enterprises: body => {
    return apiCall.post('fingerbank/all/dhcp6_enterprises/search', body).then(response => {
      return response.data
    })
  },
  fingerbankDhcpv6Enterprise: id => {
    return apiCall.get(['fingerbank', 'all', 'dhcp6_enterprise', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateDhcpv6Enterprise: data => {
    return apiCall.post('fingerbank/local/dhcp6_enterprises', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateDhcpv6Enterprise: data => {
    return apiCall.patch(['fingerbank', 'local', 'dhcp6_enterprise', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteDhcpv6Enterprise: id => {
    return apiCall.delete(['fingerbank', 'local', 'dhcp6_enterprise', id])
  },
  fingerbankMacVendors: params => {
    return apiCall.get(['fingerbank', 'all', 'mac_vendors'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchMacVendors: body => {
    return apiCall.post('fingerbank/all/mac_vendors/search', body).then(response => {
      return response.data
    })
  },
  fingerbankMacVendor: id => {
    return apiCall.get(['fingerbank', 'all', 'mac_vendor', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateMacVendor: data => {
    return apiCall.post('fingerbank/local/mac_vendors', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateMacVendor: data => {
    return apiCall.patch(['fingerbank', 'local', 'mac_vendor', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteMacVendor: id => {
    return apiCall.delete(['fingerbank', 'local', 'mac_vendor', id])
  },
  fingerbankUserAgents: params => {
    return apiCall.get(['fingerbank', 'local', 'user_agents'], { params }).then(response => {
      return response.data
    })
  },
  fingerbankSearchUserAgents: body => {
    return apiCall.post('fingerbank/local/user_agents/search', body).then(response => {
      return response.data
    })
  },
  fingerbankUserAgent: id => {
    return apiCall.get(['fingerbank', 'local', 'user_agent', id]).then(response => {
      return response.data.item
    })
  },
  fingerbankCreateUserAgent: data => {
    return apiCall.post('fingerbank/local/user_agents', data).then(response => {
      return response.data
    })
  },
  fingerbankUpdateUserAgent: data => {
    return apiCall.patch(['fingerbank', 'local', 'user_agent', data.id], data).then(response => {
      return response.data
    })
  },
  fingerbankDeleteUserAgent: id => {
    return apiCall.delete(['fingerbank', 'local', 'user_agent', id])
  },
  fingerbankUpdateDatabase: () => {
    return apiCall.post(['fingerbank', 'update_upstream_db'], {}).then(response => {
      return response.data
    })
  },

  /**
   * Firewalls
   */
  firewalls: params => {
    return apiCall.get('config/firewalls', { params }).then(response => {
      return response.data
    })
  },
  firewallsOptions: firewallType => {
    return apiCall.options(['config', 'firewalls'], { params: { type: firewallType } }).then(response => {
      return response.data
    })
  },
  firewall: id => {
    return apiCall.get(['config', 'firewall', id]).then(response => {
      return response.data.item
    })
  },
  firewallOptions: id => {
    return apiCall.options(['config', 'firewall', id]).then(response => {
      return response.data
    })
  },
  createFirewall: data => {
    return apiCall.post('config/firewalls', data).then(response => {
      return response.data
    })
  },
  updateFirewall: data => {
    return apiCall.patch(['config', 'firewall', data.id], data).then(response => {
      return response.data
    })
  },
  deleteFirewall: id => {
    return apiCall.delete(['config', 'firewall', id])
  },

  /**
   * Floating Devices
   */
  floatingDevices: params => {
    return apiCall.get('config/floating_devices', { params }).then(response => {
      return response.data
    })
  },
  floatingDevicesOptions: () => {
    return apiCall.options('config/floating_devices').then(response => {
      return response.data
    })
  },
  floatingDevice: id => {
    return apiCall.get(['config', 'floating_device', id]).then(response => {
      return response.data.item
    })
  },
  floatingDeviceOptions: id => {
    return apiCall.options(['config', 'floating_device', id]).then(response => {
      return response.data
    })
  },
  createFloatingDevice: data => {
    return apiCall.post('config/floating_devices', data).then(response => {
      return response.data
    })
  },
  updateFloatingDevice: data => {
    return apiCall.patch(['config', 'floating_device', data.id], data).then(response => {
      return response.data
    })
  },
  deleteFloatingDevice: id => {
    return apiCall.delete(['config', 'floating_device', id])
  },

  /**
   * Interfaces
   */
  interfaces: params => {
    return apiCall.get('config/interfaces', { params }).then(response => {
      return response.data
    })
  },
  interface: id => {
    return apiCall.get(['config', 'interface', id]).then(response => {
      return response.data.item
    })
  },
  createInterface: data => {
    let sanitizedData = {}
    Object.keys(data).forEach(key => {
      if (typeof data[key] !== 'boolean') {
        sanitizedData[key] = data[key]
      }
    })
    return apiCall.post('config/interfaces', sanitizedData).then(response => {
      return response.data
    })
  },
  updateInterface: data => {
    return apiCall.patch(['config', 'interface', data.id], data).then(response => {
      return response.data
    })
  },
  downInterface: id => {
    return apiCall.post(['config', 'interface', id, 'down']).then(response => {
      return response.data
    })
  },
  upInterface: id => {
    return apiCall.post(['config', 'interface', id, 'up']).then(response => {
      return response.data
    })
  },
  deleteInterface: id => {
    return apiCall.delete(['config', 'interface', id])
  },

  /**
   * Layer2 Networks
   */
  layer2Networks: params => {
    return apiCall.get('config/l2_networks', { params }).then(response => {
      return response.data
    })
  },
  layer2NetworksOptions: () => {
    return apiCall.options('config/l2_networks').then(response => {
      return response.data
    })
  },
  layer2Network: id => {
    return apiCall.get(['config', 'l2_network', id]).then(response => {
      return response.data.item
    })
  },
  layer2NetworkOptions: id => {
    return apiCall.options(['config', 'l2_network', id]).then(response => {
      return response.data
    })
  },
  updateLayer2Network: data => {
    return apiCall.patch(['config', 'l2_network', data.id], data).then(response => {
      return response.data
    })
  },

  /**
   * Maintenance Tasks
   */
  maintenanceTasks: params => {
    return apiCall.get('config/maintenance_tasks', { params }).then(response => {
      return response.data
    })
  },
  maintenanceTasksOptions: () => {
    return apiCall.options('config/maintenance_tasks').then(response => {
      return response.data
    })
  },
  maintenanceTask: id => {
    return apiCall.get(['config', 'maintenance_task', id]).then(response => {
      return response.data.item
    })
  },
  maintenanceTaskOptions: id => {
    return apiCall.options(['config', 'maintenance_task', id]).then(response => {
      return response.data
    })
  },
  createMaintenanceTask: data => {
    return apiCall.post('config/maintenance_tasks', data).then(response => {
      return response.data
    })
  },
  updateMaintenanceTask: data => {
    return apiCall.patch(['config', 'maintenance_task', data.id], data).then(response => {
      return response.data
    })
  },
  deleteMaintenanceTask: id => {
    return apiCall.delete(['config', 'maintenance_task', id])
  },

  /*
   * Network Behavior Policies
   */
  networkBehaviorPolicies: params => {
    return apiCall.get('config/network_behavior_policies', { params }).then(response => {
      return response.data
    })
  },
  networkBehaviorPoliciesOptions: () => {
    return apiCall.options('config/network_behavior_policies').then(response => {
      return response.data
    })
  },
  networkBehaviorPolicy: id => {
    return apiCall.get(['config', 'network_behavior_policy', id]).then(response => {
      return response.data.item
    })
  },
  networkBehaviorPolicyOptions: id => {
    return apiCall.options(['config', 'network_behavior_policy', id]).then(response => {
      return response.data
    })
  },
  createNetworkBehaviorPolicy: data => {
    return apiCall.post('config/network_behavior_policies', data).then(response => {
      return response.data
    })
  },
  updateNetworkBehaviorPolicy: data => {
    return apiCall.patch(['config', 'network_behavior_policy', data.id], data).then(response => {
      return response.data
    })
  },
  deleteNetworkBehaviorPolicy: id => {
    return apiCall.delete(['config', 'network_behavior_policy', id])
  },
  /**
   * PKI
   */
  pkiCas: () => {
    return apiCall.get('pki/cas').then(response => {
      const { data: { items = [] } = {} } = response
      return { items }
    })
  },
  pkiCa: id => {
    return apiCall.get(['pki', 'ca', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return item
    })
  },
  createPkiCa: data => {
    return apiCall.post('pki/cas', data).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return item
      }
    })
  },
  pkiProfiles: () => {
    return apiCall.get('pki/profiles').then(response => {
      const { data: { items = [] } = {} } = response
      return { items }
    })
  },
  pkiProfile: id => {
    return apiCall.get(['pki', 'profile', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return item
    })
  },
  createPkiProfile: data => {
    return apiCall.post('pki/profiles', data).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return item
      }
    })
  },
  updatePkiProfile: data => {
    return apiCall.patch(['pki', 'profile', data.id], data).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return item
      }
    })
  },
  pkiCerts: () => {
    return apiCall.get('pki/certs').then(response => {
      const { data: { items = [] } = {} } = response
      return { items }
    })
  },
  pkiCert: id => {
    return apiCall.get(['pki', 'cert', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return item
    })
  },
  createPkiCert: data => {
    return apiCall.post('pki/certs', data).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return item
      }
    })
  },
  downloadPkiCert: data => {
    const { id, password } = data
    return apiCall.getArrayBuffer(['pki', 'cert', id, 'download', password]).then(response => {
      return response.data
    })
  },
  emailPkiCert: id => {
    return apiCall.get(['pki', 'cert', id, 'email']).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { password } = {} } = response
        return { password }
      }
    })
  },
  revokePkiCert: data => {
    return apiCall.delete(['pki', 'cert', data.id, data.reason]).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        return true
      }
    })
  },
  pkiRevokedCerts: () => {
    return apiCall.get('pki/revokedcerts').then(response => {
      const { data: { items = [] } = {} } = response
      return { items }
    })
  },
  pkiRevokedCert: id => {
    return apiCall.get(['pki', 'revokedcert', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return item
    })
  },

  /**
   * PKI Providers
   */
  pkiProviders: params => {
    return apiCall.get('config/pki_providers', { params }).then(response => {
      return response.data
    })
  },
  pkiProvidersOptions: providerType => {
    return apiCall.options(['config', 'pki_providers'], { params: { type: providerType } }).then(response => {
      return response.data
    })
  },
  pkiProvider: id => {
    return apiCall.get(['config', 'pki_provider', id]).then(response => {
      return response.data.item
    })
  },
  pkiProviderOptions: id => {
    return apiCall.options(['config', 'pki_provider', id]).then(response => {
      return response.data
    })
  },
  createPkiProvider: data => {
    return apiCall.post('config/pki_providers', data).then(response => {
      return response.data
    })
  },
  updatePkiProvider: data => {
    return apiCall.patch(['config', 'pki_provider', data.id], data).then(response => {
      return response.data
    })
  },
  deletePkiProvider: id => {
    return apiCall.delete(['config', 'pki_provider', id])
  },

  /**
   * Portal Modules
   */
  portalModules: params => {
    return apiCall.get('config/portal_modules', { params }).then(response => {
      return response.data
    })
  },
  portalModulesOptions: sourceType => {
    return apiCall.options(['config', 'portal_modules'], { params: { type: sourceType } }).then(response => {
      return response.data
    })
  },
  portalModule: id => {
    return apiCall.get(['config', 'portal_module', id]).then(response => {
      return response.data.item
    })
  },
  portalModuleOptions: id => {
    return apiCall.options(['config', 'portal_module', id]).then(response => {
      return response.data
    })
  },
  createPortalModule: data => {
    return apiCall.post('config/portal_modules', data).then(response => {
      return response.data
    })
  },
  updatePortalModule: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'portal_module', data.id], data).then(response => {
      return response.data
    })
  },
  deletePortalModule: id => {
    return apiCall.delete(['config', 'portal_module', id])
  },

  /**
   * Provisionings
   */
  provisionings: params => {
    return apiCall.get(['config', 'provisionings'], { params }).then(response => {
      return response.data
    })
  },
  provisioningsOptions: provisioningType => {
    return apiCall.options(['config', 'provisionings'], { params: { type: provisioningType } }).then(response => {
      return response.data
    })
  },
  provisioning: id => {
    return apiCall.get(['config', 'provisioning', id]).then(response => {
      return response.data.item
    })
  },
  provisioningOptions: id => {
    return apiCall.options(['config', 'provisioning', id]).then(response => {
      return response.data
    })
  },
  createProvisioning: data => {
    return apiCall.post('config/provisionings', data).then(response => {
      return response.data
    })
  },
  updateProvisioning: data => {
    return apiCall.patch(['config', 'provisioning', data.id], data).then(response => {
      return response.data
    })
  },
  deleteProvisioning: id => {
    return apiCall.delete(['config', 'provisioning', id])
  },

  /**
   * RADIUS
   */
  radiusEaps: params => {
    return apiCall.get('config/radiusd/eap_profiles', { params }).then(response => {
      return response.data
    })
  },
  radiusEapsOptions: () => {
    return apiCall.options('config/radiusd/eap_profiles').then(response => {
      return response.data
    })
  },
  radiusEap: id => {
    return apiCall.get(['config', 'radiusd', 'eap_profile', id]).then(response => {
      return response.data.item
    })
  },
  radiusEapOptions: id => {
    return apiCall.options(['config', 'radiusd', 'eap_profile', id]).then(response => {
      return response.data
    })
  },
  createRadiusEap: data => {
    return apiCall.post('config/radiusd/eap_profiles', data).then(response => {
      return response.data
    })
  },
  updateRadiusEap: data => {
    return apiCall.patch(['config', 'radiusd', 'eap_profile', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRadiusEap: id => {
    return apiCall.delete(['config', 'radiusd', 'eap_profile', id])
  },
  radiusFasts: params => {
    return apiCall.get('config/radiusd/fast_profiles', { params }).then(response => {
      return response.data
    })
  },
  radiusFastsOptions: () => {
    return apiCall.options('config/radiusd/fast_profiles').then(response => {
      return response.data
    })
  },
  radiusFast: id => {
    return apiCall.get(['config', 'radiusd', 'fast_profile', id]).then(response => {
      return response.data.item
    })
  },
  radiusFastOptions: id => {
    return apiCall.options(['config', 'radiusd', 'fast_profile', id]).then(response => {
      return response.data
    })
  },
  createRadiusFast: data => {
    return apiCall.post('config/radiusd/fast_profiles', data).then(response => {
      return response.data
    })
  },
  updateRadiusFast: data => {
    return apiCall.patch(['config', 'radiusd', 'fast_profile', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRadiusFast: id => {
    return apiCall.delete(['config', 'radiusd', 'fast_profile', id])
  },
  radiusSsls: params => {
    return apiCall.get('config/ssl_certificates', { params }).then(response => {
      return response.data
    })
  },
  radiusSslsOptions: () => {
    return apiCall.options('config/ssl_certificates').then(response => {
      return response.data
    })
  },
  radiusSsl: id => {
    return apiCall.get(['config', 'ssl_certificate', id]).then(response => {
      return response.data.item
    })
  },
  radiusSslOptions: id => {
    return apiCall.options(['config', 'ssl_certificate', id]).then(response => {
      return response.data
    })
  },
  createRadiusSsl: data => {
    return apiCall.post('config/ssl_certificates', data).then(response => {
      return response.data
    })
  },
  updateRadiusSsl: data => {
    return apiCall.patch(['config', 'ssl_certificate', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRadiusSsl: id => {
    return apiCall.delete(['config', 'ssl_certificate', id])
  },
  radiusTlss: params => {
    return apiCall.get('config/radiusd/tls_profiles', { params }).then(response => {
      return response.data
    })
  },
  radiusTlssOptions: () => {
    return apiCall.options('config/radiusd/tls_profiles').then(response => {
      return response.data
    })
  },
  radiusTls: id => {
    return apiCall.get(['config', 'radiusd', 'tls_profile', id]).then(response => {
      return response.data.item
    })
  },
  radiusTlsOptions: id => {
    return apiCall.options(['config', 'radiusd', 'tls_profile', id]).then(response => {
      return response.data
    })
  },
  createRadiusTls: data => {
    return apiCall.post('config/radiusd/tls_profiles', data).then(response => {
      return response.data
    })
  },
  updateRadiusTls: data => {
    return apiCall.patch(['config', 'radiusd', 'tls_profile', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRadiusTls: id => {
    return apiCall.delete(['config', 'radiusd', 'tls_profile', id])
  },
  radiusOcsps: params => {
    return apiCall.get('config/radiusd/ocsp_profiles', { params }).then(response => {
      return response.data
    })
  },
  radiusOcspsOptions: () => {
    return apiCall.options('config/radiusd/ocsp_profiles').then(response => {
      return response.data
    })
  },
  radiusOcsp: id => {
    return apiCall.get(['config', 'radiusd', 'ocsp_profile', id]).then(response => {
      return response.data.item
    })
  },
  radiusOcspOptions: id => {
    return apiCall.options(['config', 'radiusd', 'ocsp_profile', id]).then(response => {
      return response.data
    })
  },
  createRadiusOcsp: data => {
    return apiCall.post('config/radiusd/ocsp_profiles', data).then(response => {
      return response.data
    })
  },
  updateRadiusOcsp: data => {
    return apiCall.patch(['config', 'radiusd', 'ocsp_profile', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRadiusOcsp: id => {
    return apiCall.delete(['config', 'radiusd', 'ocsp_profile', id])
  },

  /**
   * Realms
   */
  realms: (tenantId, params) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.get('config/realms', { params, headers }).then(response => {
      return response.data
    })
  },
  realmsOptions: () => {
    return apiCall.options('config/realms').then(response => {
      return response.data
    })
  },
  realm: (tenantId, id) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.get(['config', 'realm', id], { headers }).then(response => {
      return response.data.item
    })
  },
  realmOptions: (tenantId, id) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.options(['config', 'realm', id], { headers }).then(response => {
      return response.data
    })
  },
  createRealm: (tenantId, item) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.post('config/realms', item, { headers }).then(response => {
      return response.data
    })
  },
  updateRealm: (tenantId, item) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.patch(['config', 'realm', item.id], item, { headers }).then(response => {
      return response.data
    })
  },
  deleteRealm: (tenantId, id) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.delete(['config', 'realm', id], { headers })
  },
  sortRealms: (tenantId, items) => {
    const headers = {
      'X-PacketFence-Tenant-Id': tenantId
    }
    return apiCall.patch('config/realms/sort_items', items, { headers }).then(response => {
      return response
    })
  },

  /**
   * Roles
   */
  roles: params => {
    return apiCall.get('config/roles', { params }).then(response => {
      return response.data
    })
  },
  rolesOptions: () => {
    return apiCall.options('config/roles').then(response => {
      return response.data
    })
  },
  role: id => {
    return apiCall.get(['config', 'role', id]).then(response => {
      return response.data.item
    })
  },
  roleOptions: id => {
    return apiCall.options(['config', 'role', id]).then(response => {
      return response.data
    })
  },
  createRole: data => {
    return apiCall.post('config/roles', data).then(response => {
      return response.data
    })
  },
  updateRole: data => {
    return apiCall.patch(['config', 'role', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRole: id => {
    return apiCall.delete(['config', 'role', id])
  },
  reassignRole: data => {
    return apiCall.patch(['config', 'role', data.from, 'reassign'], { id: data.to })
  },

  /**
   * Routed Networks
   */
  routedNetworks: params => {
    return apiCall.get('config/routed_networks', { params }).then(response => {
      return response.data
    })
  },
  routedNetworksOptions: () => {
    return apiCall.options('config/routed_networks').then(response => {
      return response.data
    })
  },
  routedNetwork: id => {
    return apiCall.get(['config', 'routed_network', id]).then(response => {
      return response.data.item
    })
  },
  routedNetworkOptions: id => {
    return apiCall.options(['config', 'routed_network', id]).then(response => {
      return response.data
    })
  },
  createRoutedNetwork: data => {
    return apiCall.post('config/routed_networks', data).then(response => {
      return response.data
    })
  },
  updateRoutedNetwork: data => {
    return apiCall.patch(['config', 'routed_network', data.id], data).then(response => {
      return response.data
    })
  },
  deleteRoutedNetwork: id => {
    return apiCall.delete(['config', 'routed_network', id])
  },

  /**
   * Scans
   */
  scanEngines: params => {
    return apiCall.get(['config', 'scans'], { params }).then(response => {
      return response.data
    })
  },
  scanEnginesOptions: scanType => {
    return apiCall.options(['config', 'scans'], { params: { type: scanType } }).then(response => {
      return response.data
    })
  },
  scanEngine: id => {
    return apiCall.get(['config', 'scan', id]).then(response => {
      return response.data.item
    })
  },
  scanEngineOptions: id => {
    return apiCall.options(['config', 'scan', id]).then(response => {
      return response.data
    })
  },
  createScanEngine: data => {
    return apiCall.post('config/scans', data).then(response => {
      return response.data
    })
  },
  updateScanEngine: data => {
    return apiCall.patch(['config', 'scan', data.id], data).then(response => {
      return response.data
    })
  },
  deleteScanEngine: id => {
    return apiCall.delete(['config', 'scan', id])
  },

  /**
   * Security Events
   */
  securityEvents: params => {
    return apiCall.get('config/security_events', { params }).then(response => {
      return response.data
    })
  },
  securityEventsOptions: () => {
    return apiCall.options('config/security_events').then(response => {
      return response.data
    })
  },
  securityEvent: id => {
    return apiCall.get(['config', 'security_event', id]).then(response => {
      return response.data.item
    })
  },
  securityEventOptions: id => {
    return apiCall.options(['config', 'security_event', id]).then(response => {
      return response.data
    })
  },
  createSecurityEvent: data => {
    return apiCall.post('config/security_events', data).then(response => {
      return response.data
    })
  },
  updateSecurityEvent: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'security_event', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSecurityEvent: id => {
    return apiCall.delete(['config', 'security_event', id])
  },

  /**
   * SSL Certificates
   */
  certificate: id => {
    return apiCall.get(['config', 'certificate', id]).then(response => {
      return response.data
    })
  },
  certificateInfo: id => {
    return apiCall.get(['config', 'certificate', id, 'info']).then(response => {
      return response.data
    })
  },
  createCertificate: data => {
    return apiCall.put(['config', 'certificate', data.id], data, { params: { check_chain: data.check_chain } }).then(response => {
      return response.data
    })
  },
  createLetsEncryptCertificate: data => {
    return apiCall.put(['config', 'certificate', data.id, 'lets_encrypt'], data).then(response => {
      return response.data
    })
  },
  generateCertificateSigningRequest: data => {
    return apiCall.post(['config', 'certificate', data.id, 'generate_csr'], data).then(response => {
      return response.data
    })
  },
  testLetsEncrypt: domain => {
    return apiCall.get('config/certificates/lets_encrypt/test', { params: { domain } }).then(response => {
      return response.data
    })
  },

  /**
   * Switches
   */
  switches: params => {
    return apiCall.get(['config', 'switches'], { params: { ...params, raw: 1 } }).then(response => {
      return response.data
    })
  },
  switchesOptions: switchGroup => {
    if (switchGroup) {
      return apiCall.options(['config', 'switches'], { params: { type: switchGroup } }).then(response => {
        return response.data
      })
    } else {
      return apiCall.options(['config', 'switches']).then(response => {
        return response.data
      })
    }
  },
  switchesBulkImport: body => {
    return apiCall.post('config/switches/bulk_import', body).then(response => {
      return response.data.items
    })
  },
  switche: id => {
    return apiCall.get(['config', 'switch', id], { params: { skip_inheritance: true } }).then(response => {
      return response.data.item
    })
  },
  switcheQuiet: id => {
    return apiCall.getQuiet(['config', 'switch', id], { params: { skip_inheritance: true } }).then(response => {
      return response.data.item
    })
  },
  switchOptions: id => {
    return apiCall.options(['config', 'switch', id]).then(response => {
      return response.data
    })
  },
  createSwitch: data => {
    const post = data.quiet ? 'postQuiet' : 'post'
    return apiCall[post]('config/switches', data).then(response => {
      return response.data
    })
  },
  updateSwitch: data => {
    const patch = data.quiet ? 'patchQuiet' : 'patch'
    return apiCall[patch](['config', 'switch', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSwitch: id => {
    return apiCall.delete(['config', 'switch', id])
  },
  invalidateSwitchCache: id => {
    return apiCall.post(['config', 'switch', id, 'invalidate_cache'])
  },

  /**
   * SwitchGroups
   */
  switchGroups: params => {
    return apiCall.get(['config', 'switch_groups'], { params: { ...params, raw: 1 } }).then(response => {
      return response.data
    })
  },
  switchGroupsOptions: () => {
    return apiCall.options('config/switch_groups').then(response => {
      return response.data
    })
  },
  switchGroup: id => {
    return apiCall.get(['config', 'switch_group', id], { params: { skip_inheritance: true } }).then(response => {
      return response.data.item
    })
  },
  switchGroupMembers: id => {
    return apiCall.get(['config', 'switch_group', id, 'members']).then(response => {
      return response.data.items
    })
  },
  switchGroupOptions: id => {
    return apiCall.options(['config', 'switch_group', id]).then(response => {
      return response.data
    })
  },
  createSwitchGroup: data => {
    return apiCall.post('config/switch_groups', data).then(response => {
      return response.data
    })
  },
  updateSwitchGroup: data => {
    return apiCall.patch(['config', 'switch_group', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSwitchGroup: id => {
    return apiCall.delete(['config', 'switch_group', id])
  },

  /**
   * Switch Templates
   */
  switchTemplates: params => {
    return apiCall.get('config/template_switches', { params }).then(response => {
      return response.data
    })
  },
  switchTemplatesOptions: () => {
    return apiCall.options('config/template_switches').then(response => {
      return response.data
    })
  },
  switchTemplate: id => {
    return apiCall.get(['config', 'template_switch', id]).then(response => {
      return response.data.item
    })
  },
  createSwitchTemplate: data => {
    return apiCall.post('config/template_switches', data).then(response => {
      return response.data
    })
  },
  updateSwitchTemplate: data => {
    return apiCall.patch(['config', 'template_switch', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSwitchTemplate: id => {
    return apiCall.delete(['config', 'template_switch', id])
  },

  /**
   * Syslog Forwarders
   */
  syslogForwarders: params => {
    return apiCall.get('config/syslog_forwarders', { params }).then(response => {
      return response.data
    })
  },
  syslogForwardersOptions: syslogForwarderType => {
    return apiCall.options(['config', 'syslog_forwarders'], { params: { type: syslogForwarderType } }).then(response => {
      return response.data
    })
  },
  syslogForwarder: id => {
    return apiCall.get(['config', 'syslog_forwarder', id]).then(response => {
      return response.data.item
    })
  },
  syslogForwarderOptions: id => {
    return apiCall.options(['config', 'syslog_forwarder', id]).then(response => {
      return response.data
    })
  },
  createSyslogForwarder: data => {
    return apiCall.post('config/syslog_forwarders', data).then(response => {
      return response.data
    })
  },
  updateSyslogForwarder: data => {
    return apiCall.patch(['config', 'syslog_forwarder', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSyslogForwarder: id => {
    return apiCall.delete(['config', 'syslog_forwarder', id])
  },

  /**
   * Syslog Parsers
   */
  syslogParsers: params => {
    return apiCall.get('config/syslog_parsers', { params }).then(response => {
      return response.data
    })
  },
  syslogParsersOptions: syslogParserType => {
    return apiCall.options(['config', 'syslog_parsers'], { params: { type: syslogParserType } }).then(response => {
      return response.data
    })
  },
  syslogParser: id => {
    return apiCall.get(['config', 'syslog_parser', id]).then(response => {
      return response.data.item
    })
  },
  syslogParserOptions: id => {
    return apiCall.options(['config', 'syslog_parser', id]).then(response => {
      return response.data
    })
  },
  createSyslogParser: data => {
    return apiCall.post('config/syslog_parsers', data).then(response => {
      return response.data
    })
  },
  updateSyslogParser: data => {
    return apiCall.patch(['config', 'syslog_parser', data.id], data).then(response => {
      return response.data
    })
  },
  deleteSyslogParser: id => {
    return apiCall.delete(['config', 'syslog_parser', id])
  },
  dryRunSyslogParser: data => {
    return apiCall.post('config/syslog_parsers/dry_run', data).then(response => {
      return response.data
    })
  },

  /**
   * Traffic Shaping Policies
   */
  trafficShapingPolicies: params => {
    return apiCall.get('config/traffic_shaping_policies', { params }).then(response => {
      return response.data
    })
  },
  trafficShapingPoliciesOptions: () => {
    return apiCall.options('config/traffic_shaping_policies').then(response => {
      return response.data
    })
  },
  trafficShapingPolicy: id => {
    return apiCall.get(['config', 'traffic_shaping_policy', id]).then(response => {
      return response.data.item
    })
  },
  trafficShapingPolicyOptions: id => {
    return apiCall.options(['config', 'traffic_shaping_policy', id]).then(response => {
      return response.data
    })
  },
  createTrafficShapingPolicy: data => {
    return apiCall.post('config/traffic_shaping_policies', data).then(response => {
      return response.data
    })
  },
  updateTrafficShapingPolicy: data => {
    return apiCall.patch(['config', 'traffic_shaping_policy', data.id], data).then(response => {
      return response.data
    })
  },
  deleteTrafficShapingPolicy: id => {
    return apiCall.delete(['config', 'traffic_shaping_policy', id])
  },

  /**
   * WMI Rules
   */
  wmiRules: params => {
    return apiCall.get('config/wmi_rules', { params }).then(response => {
      return response.data
    })
  },
  wmiRulesOptions: () => {
    return apiCall.options('config/wmi_rules').then(response => {
      return response.data
    })
  },
  wmiRule: id => {
    return apiCall.get(['config', 'wmi_rule', id]).then(response => {
      return response.data.item
    })
  },
  wmiRuleOptions: id => {
    return apiCall.options(['config', 'wmi_rule', id]).then(response => {
      return response.data
    })
  },
  createWmiRule: data => {
    return apiCall.post('config/wmi_rules', data).then(response => {
      return response.data
    })
  },
  updateWmiRule: data => {
    return apiCall.patch(['config', 'wmi_rule', data.id], data).then(response => {
      return response.data
    })
  },
  deleteWmiRule: id => {
    return apiCall.delete(['config', 'wmi_rule', id])
  },

  /**
   * Wrix Locations
   */
  wrixLocations: params => {
    return apiCall.get('wrix_locations', { params }).then(response => {
      return response.data
    })
  },
  wrixLocation: id => {
    return apiCall.get(['wrix_location', id]).then(response => {
      return response.data.item
    })
  },
  createWrixLocation: data => {
    return apiCall.post('wrix_locations', data).then(response => {
      return response.data
    })
  },
  updateWrixLocation: data => {
    return apiCall.patch(['wrix_location', data.id], data).then(response => {
      return response.data
    })
  },
  deleteWrixLocation: id => {
    return apiCall.delete(['wrix_location', id])
  }
}
