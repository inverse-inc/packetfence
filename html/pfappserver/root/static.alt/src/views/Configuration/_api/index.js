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
