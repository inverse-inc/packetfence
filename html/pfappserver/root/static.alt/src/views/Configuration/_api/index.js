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
  }
}
