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
    return apiCall.get(`config/admin_role/${id}`).then(response => {
      return response.data.item
    })
  },
  adminRoleOptions: id => {
    return apiCall.options(`config/admin_role/${id}`).then(response => {
      return response.data
    })
  },
  createAdminRole: data => {
    return apiCall.post('config/admin_roles', data).then(response => {
      return response.data
    })
  },
  updateAdminRole: data => {
    return apiCall.patch(`config/admin_role/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteAdminRole: id => {
    return apiCall.delete(`config/admin_role/${id}`)
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
    return apiCall.options(`config/sources?type=${sourceType}`).then(response => {
      return response.data
    })
  },
  authenticationSource: id => {
    return apiCall.get(`config/source/${id}`).then(response => {
      return response.data.item
    })
  },
  authenticationSourceOptions: id => {
    return apiCall.options(`config/source/${id}`).then(response => {
      return response.data
    })
  },
  createAuthenticationSource: data => {
    return apiCall.post('config/sources', data).then(response => {
      return response.data
    })
  },
  updateAuthenticationSource: data => {
    return apiCall.patch(`config/source/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteAuthenticationSource: id => {
    return apiCall.delete(`config/source/${id}`)
  },
  testAuthenticationSource: data => {
    return apiCall.post(`config/sources/test`, data).then(response => {
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
    return apiCall.get(`config/base/${id}`).then(response => {
      return response.data.item
    })
  },
  baseOptions: id => {
    return apiCall.options(`config/base/${id}`).then(response => {
      return response.data
    })
  },
  updateBase: data => {
    return apiCall.patch(`config/base/${data.id}`, data).then(response => {
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
    return apiCall.get(`config/billing_tier/${id}`).then(response => {
      return response.data.item
    })
  },
  billingTierOptions: id => {
    return apiCall.options(`config/billing_tier/${id}`).then(response => {
      return response.data
    })
  },
  createBillingTier: data => {
    return apiCall.post('config/billing_tiers', data).then(response => {
      return response.data
    })
  },
  updateBillingTier: data => {
    return apiCall.patch(`config/billing_tier/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteBillingTier: id => {
    return apiCall.delete(`config/billing_tier/${id}`)
  },

  /**
   * Connection Profiles
   */
  connectionProfiles: params => {
    return apiCall.get(`config/connection_profiles`, { params }).then(response => {
      return response.data
    })
  },
  connectionProfilesOptions: () => {
    return apiCall.options('config/connection_profiles').then(response => {
      return response.data
    })
  },
  connectionProfile: id => {
    return apiCall.get(`config/connection_profile/${id}`).then(response => {
      return response.data.item
    })
  },
  connectionProfileOptions: id => {
    return apiCall.options(`config/connection_profile/${id}`).then(response => {
      return response.data
    })
  },
  createConnectionProfile: data => {
    return apiCall.post('config/connection_profiles', data).then(response => {
      return response.data
    })
  },
  updateConnectionProfile: data => {
    return apiCall.patch(`config/connection_profile/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteConnectionProfile: id => {
    return apiCall.delete(`config/connection_profile/${id}`)
  },

  /**
   * Connection Profiles Files
   */
  connectionProfileFiles: params => {
    return apiCall.get(`config/connection_profile/${params.id}/files`, { params }).then(response => {
      return response.data
    })
  },
  connectionProfileFile: params => {
    const get = params.quiet ? 'getQuiet' : 'get'
    return apiCall[get](`config/connection_profile/${params.id}/files/${params.filename}`).then(response => {
      return response.data
    })
  },
  createConnectionProfileFile: params => {
    return apiCall.put(`config/connection_profile/${params.id}/files/${params.filename}`, params.content).then(response => {
      return response.data
    })
  },
  updateConnectionProfileFile: params => {
    return apiCall.patch(`config/connection_profile/${params.id}/files/${params.filename}`, params.content).then(response => {
      return response.data
    })
  },
  deleteConnectionProfileFile: params => {
    return apiCall.delete(`config/connection_profile/${params.id}/files/${params.filename}`)
  },

  /**
   * Device Registration
   */
  deviceRegistrations: params => {
    return apiCall.get('config/device_registrations', { params }).then(response => {
      return response.data
    })
  },
  deviceRegistrationsOptions: () => {
    return apiCall.options('config/device_registrations').then(response => {
      return response.data
    })
  },
  deviceRegistration: id => {
    return apiCall.get(`config/device_registration/${id}`).then(response => {
      return response.data.item
    })
  },
  deviceRegistrationOptions: id => {
    return apiCall.options(`config/device_registration/${id}`).then(response => {
      return response.data
    })
  },
  createDeviceRegistration: data => {
    return apiCall.post('config/device_registrations', data).then(response => {
      return response.data
    })
  },
  updateDeviceRegistration: data => {
    return apiCall.patch(`config/device_registration/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteDeviceRegistration: id => {
    return apiCall.delete(`config/device_registration/${id}`)
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
    return apiCall.get(`config/domain/${id}`).then(response => {
      return response.data.item
    })
  },
  domainOptions: id => {
    return apiCall.options(`config/domain/${id}`).then(response => {
      return response.data
    })
  },
  createDomain: data => {
    return apiCall.post('config/domains', data).then(response => {
      return response.data
    })
  },
  updateDomain: data => {
    return apiCall.patch(`config/domain/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteDomain: id => {
    return apiCall.delete(`config/domain/${id}`)
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
    return apiCall.get(`config/filter/${id}`).then(response => {
      return response.data
    })
  },
  updateFilter: (id, filter) => {
    return apiCall.put(`config/filter/${id}`, filter).then(response => {
      return response.data
    })
  },

  /**
   * Fingerbank Profiling
   */
  profilingGeneralSettings: params => {
    return apiCall.get(`config/TODO`, { params }).then(response => {
      return response.data.item
    })
  },
  profilingUpdateGeneralSettings: params => {
    return apiCall.get(`config/TODO`, { params }).then(response => {
      return response.data
    })
  },
  profilingDeviceChangeDetection: params => {
    return apiCall.get(`config/TODO`, { params }).then(response => {
      return response.data.item
    })
  },
  profilingUpdateDeviceChangeDetection: params => {
    return apiCall.get(`config/TODO`, { params }).then(response => {
      return response.data
    })
  },
  profilingCombinations: params => {
    return apiCall.get(`config/TODO`, { params }).then(response => {
      return response.data
    })
  },
  profilingCombination: id => {
    return apiCall.get(`config/TODO/${id}`).then(response => {
      return response.data.item
    })
  },
  profilingCreateCombination: data => {
    return apiCall.post('config/TODO', data).then(response => {
      return response.data
    })
  },
  profilingUpdateCombination: data => {
    return apiCall.patch(`config/TODO/${data.id}`, data).then(response => {
      return response.data
    })
  },
  profilingDeleteCombination: id => {
    return apiCall.delete(`config/TODO/${id}`)
  },
  profilingDevices: params => {
    return apiCall.get(`config/TODO`, { params }).then(response => {
      return response.data
    })
  },
  profilingDevice: id => {
    return apiCall.get(`config/TODO/${id}`).then(response => {
      return response.data.item
    })
  },
  profilingCreateDevice: data => {
    return apiCall.post('config/TODO', data).then(response => {
      return response.data
    })
  },
  profilingUpdateDevice: data => {
    return apiCall.patch(`config/TODO/${data.id}`, data).then(response => {
      return response.data
    })
  },
  profilingDeleteDevice: id => {
    return apiCall.delete(`config/TODO/${id}`)
  },
  profilingDhcpFingerprints: params => {
    return apiCall.get(`config/TODO`, { params }).then(response => {
      return response.data
    })
  },
  profilingDhcpFingerprint: id => {
    return apiCall.get(`config/TODO/${id}`).then(response => {
      return response.data.item
    })
  },
  profilingCreateDhcpFingerprint: data => {
    return apiCall.post('config/TODO', data).then(response => {
      return response.data
    })
  },
  profilingUpdateDhcpFingerprint: data => {
    return apiCall.patch(`config/TODO/${data.id}`, data).then(response => {
      return response.data
    })
  },
  profilingDeleteDhcpFingerprint: id => {
    return apiCall.delete(`config/TODO/${id}`)
  },
  profilingDhcpVendors: params => {
    return apiCall.get(`config/TODO`, { params }).then(response => {
      return response.data
    })
  },
  profilingDhcpVendor: id => {
    return apiCall.get(`config/TODO/${id}`).then(response => {
      return response.data.item
    })
  },
  profilingCreateDhcpVendor: data => {
    return apiCall.post('config/TODO', data).then(response => {
      return response.data
    })
  },
  profilingUpdateDhcpVendor: data => {
    return apiCall.patch(`config/TODO/${data.id}`, data).then(response => {
      return response.data
    })
  },
  profilingDeleteDhcpVendor: id => {
    return apiCall.delete(`config/TODO/${id}`)
  },
  profilingDhcpv6Fingerprints: params => {
    return apiCall.get(`config/TODO`, { params }).then(response => {
      return response.data
    })
  },
  profilingDhcpv6Fingerprint: id => {
    return apiCall.get(`config/TODO/${id}`).then(response => {
      return response.data.item
    })
  },
  profilingCreateDhcpv6Fingerprint: data => {
    return apiCall.post('config/TODO', data).then(response => {
      return response.data
    })
  },
  profilingUpdateDhcpv6Fingerprint: data => {
    return apiCall.patch(`config/TODO/${data.id}`, data).then(response => {
      return response.data
    })
  },
  profilingDeleteDhcpv6Fingerprint: id => {
    return apiCall.delete(`config/TODO/${id}`)
  },
  profilingDhcpv6Enterprises: params => {
    return apiCall.get(`config/TODO`, { params }).then(response => {
      return response.data
    })
  },
  profilingDhcpv6Enterprise: id => {
    return apiCall.get(`config/TODO/${id}`).then(response => {
      return response.data.item
    })
  },
  profilingCreateDhcpv6Enterprise: data => {
    return apiCall.post('config/TODO', data).then(response => {
      return response.data
    })
  },
  profilingUpdateDhcpv6Enterprise: data => {
    return apiCall.patch(`config/TODO/${data.id}`, data).then(response => {
      return response.data
    })
  },
  profilingDeleteDhcpv6Enterprise: id => {
    return apiCall.delete(`config/TODO/${id}`)
  },
  profilingMacVendors: params => {
    return apiCall.get(`config/TODO`, { params }).then(response => {
      return response.data
    })
  },
  profilingMacVendor: id => {
    return apiCall.get(`config/TODO/${id}`).then(response => {
      return response.data.item
    })
  },
  profilingCreateMacVendor: data => {
    return apiCall.post('config/TODO', data).then(response => {
      return response.data
    })
  },
  profilingUpdateMacVendor: data => {
    return apiCall.patch(`config/TODO/${data.id}`, data).then(response => {
      return response.data
    })
  },
  profilingDeleteMacVendor: id => {
    return apiCall.delete(`config/TODO/${id}`)
  },
  profilingUserAgents: params => {
    return apiCall.get(`config/TODO`, { params }).then(response => {
      return response.data
    })
  },
  profilingUserAgent: id => {
    return apiCall.get(`config/TODO/${id}`).then(response => {
      return response.data.item
    })
  },
  profilingCreateUserAgent: data => {
    return apiCall.post('config/TODO', data).then(response => {
      return response.data
    })
  },
  profilingUpdateUserAgent: data => {
    return apiCall.patch(`config/TODO/${data.id}`, data).then(response => {
      return response.data
    })
  },
  profilingDeleteUserAgent: id => {
    return apiCall.delete(`config/TODO/${id}`)
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
    return apiCall.options(`config/firewalls?type=${firewallType}`).then(response => {
      return response.data
    })
  },
  firewall: id => {
    return apiCall.get(`config/firewall/${id}`).then(response => {
      return response.data.item
    })
  },
  firewallOptions: id => {
    return apiCall.options(`config/firewall/${id}`).then(response => {
      return response.data
    })
  },
  createFirewall: data => {
    return apiCall.post('config/firewalls', data).then(response => {
      return response.data
    })
  },
  updateFirewall: data => {
    return apiCall.patch(`config/firewall/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteFirewall: id => {
    return apiCall.delete(`config/firewall/${id}`)
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
    return apiCall.get(`config/floating_device/${id}`).then(response => {
      return response.data.item
    })
  },
  floatingDeviceOptions: id => {
    return apiCall.options(`config/floating_device/${id}`).then(response => {
      return response.data
    })
  },
  createFloatingDevice: data => {
    return apiCall.post('config/floating_devices', data).then(response => {
      return response.data
    })
  },
  updateFloatingDevice: data => {
    return apiCall.patch(`config/floating_device/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteFloatingDevice: id => {
    return apiCall.delete(`config/floating_device/${id}`)
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
    return apiCall.get(`config/maintenance_task/${id}`).then(response => {
      return response.data.item
    })
  },
  maintenanceTaskOptions: id => {
    return apiCall.options(`config/maintenance_task/${id}`).then(response => {
      return response.data
    })
  },
  createMaintenanceTask: data => {
    return apiCall.post('config/maintenance_tasks', data).then(response => {
      return response.data
    })
  },
  updateMaintenanceTask: data => {
    return apiCall.patch(`config/maintenance_task/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteMaintenanceTask: id => {
    return apiCall.delete(`config/maintenance_task/${id}`)
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
    return apiCall.options(`config/pki_providers?type=${providerType}`).then(response => {
      return response.data
    })
  },
  pkiProvider: id => {
    return apiCall.get(`config/pki_provider/${id}`).then(response => {
      return response.data.item
    })
  },
  pkiProviderOptions: id => {
    return apiCall.options(`config/pki_provider/${id}`).then(response => {
      return response.data
    })
  },
  createPkiProvider: data => {
    return apiCall.post('config/pki_providers', data).then(response => {
      return response.data
    })
  },
  updatePkiProvider: data => {
    return apiCall.patch(`config/pki_provider/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deletePkiProvider: id => {
    return apiCall.delete(`config/pki_provider/${id}`)
  },

  /**
   * Portal Modules
   */
  portalModules: params => {
    return apiCall.get('config/portal_modules', { params }).then(response => {
      return response.data
    })
  },
  portalModule: id => {
    return apiCall.get(`config/portal_module/${id}`).then(response => {
      return response.data.item
    })
  },
  updatePortalModule: data => {
    return apiCall.patch(`config/portal_module/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deletePortalModule: id => {
    return apiCall.delete(`config/portal_module/${id}`)
  },

  /**
   * Provisionings
   */
  provisionings: params => {
    return apiCall.get(`config/provisionings`, { params }).then(response => {
      return response.data
    })
  },
  provisioningsOptions: provisioningType => {
    return apiCall.options(`config/provisionings?type=${provisioningType}`).then(response => {
      return response.data
    })
  },
  provisioning: id => {
    return apiCall.get(`config/provisioning/${id}`).then(response => {
      return response.data.item
    })
  },
  provisioningOptions: id => {
    return apiCall.options(`config/provisioning/${id}`).then(response => {
      return response.data
    })
  },
  createProvisioning: data => {
    return apiCall.post('config/provisionings', data).then(response => {
      return response.data
    })
  },
  updateProvisioning: data => {
    return apiCall.patch(`config/provisioning/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteProvisioning: id => {
    return apiCall.delete(`config/provisioning/${id}`)
  },

  /**
   * Realms
   */
  realms: params => {
    return apiCall.get('config/realms', { params }).then(response => {
      return response.data
    })
  },
  realmsOptions: () => {
    return apiCall.options('config/realms').then(response => {
      return response.data
    })
  },
  realm: id => {
    return apiCall.get(`config/realm/${id}`).then(response => {
      return response.data.item
    })
  },
  realmOptions: id => {
    return apiCall.options(`config/realm/${id}`).then(response => {
      return response.data
    })
  },
  createRealm: data => {
    return apiCall.post('config/realms', data).then(response => {
      return response.data
    })
  },
  updateRealm: data => {
    return apiCall.patch(`config/realm/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteRealm: id => {
    return apiCall.delete(`config/realm/${id}`)
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
    return apiCall.get(`config/role/${id}`).then(response => {
      return response.data.item
    })
  },
  roleOptions: id => {
    return apiCall.options(`config/role/${id}`).then(response => {
      return response.data
    })
  },
  createRole: data => {
    return apiCall.post('config/roles', data).then(response => {
      return response.data
    })
  },
  updateRole: data => {
    return apiCall.patch(`config/role/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteRole: id => {
    return apiCall.delete(`config/role/${id}`)
  },

  /**
   * Scans
   */
  scanEngines: params => {
    return apiCall.get(`config/scans`, { params }).then(response => {
      return response.data
    })
  },
  scanEnginesOptions: scanType => {
    return apiCall.options(`config/scans?type=${scanType}`).then(response => {
      return response.data
    })
  },
  scanEngine: id => {
    return apiCall.get(`config/scan/${id}`).then(response => {
      return response.data.item
    })
  },
  scanEngineOptions: id => {
    return apiCall.options(`config/scan/${id}`).then(response => {
      return response.data
    })
  },
  createScanEngine: data => {
    return apiCall.post('config/scans', data).then(response => {
      return response.data
    })
  },
  updateScanEngine: data => {
    return apiCall.patch(`config/scan/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteScanEngine: id => {
    return apiCall.delete(`config/scan/${id}`)
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
    return apiCall.get(`config/security_event/${id}`).then(response => {
      return response.data.item
    })
  },
  securityEventOptions: id => {
    return apiCall.options(`config/security_event/${id}`).then(response => {
      return response.data
    })
  },
  createSecurityEvent: data => {
    return apiCall.post('config/security_events', data).then(response => {
      return response.data
    })
  },
  updateSecurityEvent: data => {
    return apiCall.patch(`config/security_event/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteSecurityEvent: id => {
    return apiCall.delete(`config/security_event/${id}`)
  },

  /**
   * Services
   */
  services: () => {
    return apiCall.get('services').then(response => {
      return response.data.items
    })
  },
  service: name => {
    return apiCall.get(`service/${name}/status`).then(response => {
      return response.data
    })
  },
  disableService: name => {
    return apiCall.post(`service/${name}/disable`).then(response => {
      return response.data
    })
  },
  enableService: name => {
    return apiCall.post(`service/${name}/enable`).then(response => {
      return response.data
    })
  },
  restartService: name => {
    return apiCall.post(`service/${name}/restart`).then(response => {
      return response.data
    })
  },
  startService: name => {
    return apiCall.post(`service/${name}/start`).then(response => {
      return response.data
    })
  },
  stopService: name => {
    return apiCall.post(`service/${name}/stop`).then(response => {
      return response.data
    })
  },

  /**
   * SSL Certificates
   */
  certificate: id => {
    return apiCall.get(`config/certificate/${id}`).then(response => {
      return response.data
    })
  },
  certificateInfo: id => {
    return apiCall.get(`config/certificate/${id}/info`).then(response => {
      return response.data
    })
  },
  createCertificate: data => {
    return apiCall.put(`config/certificate/${data.id}`, data).then(response => {
      return response.data
    })
  },
  generateCertificateSigningRequest: data => {
    return apiCall.post(`config/certificate/${data.id}/generate_csr`, data).then(response => {
      return response.data
    })
  },
  testLetsEncrypt: domain => {
    return apiCall.get('config/certificates/lets_encrypt/test', { params: { domain } }).then(response => {
      return response.data
    })
  },
  createLetsEncryptCertificate: data => {
    return apiCall.put(`config/certificate/${data.id}/lets_encrypt`, data).then(response => {
      return response.data
    })
  },

  /**
   * Switches
   */
  switches: params => {
    return apiCall.get(`config/switches`, { params }).then(response => {
      return response.data
    })
  },
  switchesOptions: switchGroup => {
    return apiCall.options(`config/switches?type=${switchGroup}`).then(response => {
      return response.data
    })
  },
  switche: id => {
    return apiCall.get(`config/switch/${encodeURIComponent(id)}`).then(response => {
      return response.data.item
    })
  },
  switchOptions: id => {
    return apiCall.options(`config/switch/${encodeURIComponent(id)}`).then(response => {
      return response.data
    })
  },
  createSwitch: data => {
    return apiCall.post('config/switches', data).then(response => {
      return response.data
    })
  },
  updateSwitch: data => {
    return apiCall.patch(`config/switch/${encodeURIComponent(data.id)}`, data).then(response => {
      return response.data
    })
  },
  deleteSwitch: id => {
    return apiCall.delete(`config/switch/${encodeURIComponent(id)}`)
  },

  /**
   * SwitchGroups
   */
  switchGroups: params => {
    return apiCall.get(`config/switch_groups`, { params }).then(response => {
      return response.data
    })
  },
  switchGroupsOptions: () => {
    return apiCall.options('config/switch_groups').then(response => {
      return response.data
    })
  },
  switchGroup: id => {
    return apiCall.get(`config/switch_group/${encodeURIComponent(id)}`).then(response => {
      return response.data.item
    })
  },
  switchGroupOptions: id => {
    return apiCall.options(`config/switch_group/${encodeURIComponent(id)}`).then(response => {
      return response.data
    })
  },
  createSwitchGroup: data => {
    return apiCall.post('config/switch_groups', data).then(response => {
      return response.data
    })
  },
  updateSwitchGroup: data => {
    return apiCall.patch(`config/switch_group/${encodeURIComponent(data.id)}`, data).then(response => {
      return response.data
    })
  },
  deleteSwitchGroup: id => {
    return apiCall.delete(`config/switch_group/${encodeURIComponent(id)}`)
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
    return apiCall.options(`config/syslog_forwarders?type=${syslogForwarderType}`).then(response => {
      return response.data
    })
  },
  syslogForwarder: id => {
    return apiCall.get(`config/syslog_forwarder/${id}`).then(response => {
      return response.data.item
    })
  },
  syslogForwarderOptions: id => {
    return apiCall.options(`config/syslog_forwarder/${id}`).then(response => {
      return response.data
    })
  },
  createSyslogForwarder: data => {
    return apiCall.post('config/syslog_forwarders', data).then(response => {
      return response.data
    })
  },
  updateSyslogForwarder: data => {
    return apiCall.patch(`config/syslog_forwarder/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteSyslogForwarder: id => {
    return apiCall.delete(`config/syslog_forwarder/${id}`)
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
    return apiCall.options(`config/syslog_parsers?type=${syslogParserType}`).then(response => {
      return response.data
    })
  },
  syslogParser: id => {
    return apiCall.get(`config/syslog_parser/${id}`).then(response => {
      return response.data.item
    })
  },
  syslogParserOptions: id => {
    return apiCall.options(`config/syslog_parser/${id}`).then(response => {
      return response.data
    })
  },
  createSyslogParser: data => {
    return apiCall.post('config/syslog_parsers', data).then(response => {
      return response.data
    })
  },
  updateSyslogParser: data => {
    return apiCall.patch(`config/syslog_parser/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteSyslogParser: id => {
    return apiCall.delete(`config/syslog_parser/${id}`)
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
    return apiCall.get(`config/traffic_shaping_policy/${id}`).then(response => {
      return response.data.item
    })
  },
  trafficShapingPolicyOptions: id => {
    return apiCall.options(`config/traffic_shaping_policy/${id}`).then(response => {
      return response.data
    })
  },
  createTrafficShapingPolicy: data => {
    return apiCall.post('config/traffic_shaping_policies', data).then(response => {
      return response.data
    })
  },
  updateTrafficShapingPolicy: data => {
    return apiCall.patch(`config/traffic_shaping_policy/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteTrafficShapingPolicy: id => {
    return apiCall.delete(`config/traffic_shaping_policy/${id}`)
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
    return apiCall.get(`wrix_location/${id}`).then(response => {
      return response.data.item
    })
  },
  createWrixLocation: data => {
    return apiCall.post('wrix_locations', data).then(response => {
      return response.data
    })
  },
  updateWrixLocation: data => {
    return apiCall.patch(`wrix_location/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteWrixLocation: id => {
    return apiCall.delete(`wrix_location/${id}`)
  }
}
