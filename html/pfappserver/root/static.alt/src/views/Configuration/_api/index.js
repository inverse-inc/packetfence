import apiCall from '@/utils/api'

export default {
  /**
   * Authentication Sources
   */
  authenticationSources: params => {
    return apiCall.get('config/sources', { params }).then(response => {
      return response.data
    })
  },
  authenticationSource: id => {
    return apiCall.get(`config/source/${id}`).then(response => {
      return response.data.item
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
   * Billing Tiers
   */
  billingTier: id => {
    return apiCall.get(`config/billing_tier/${id}`).then(response => {
      return response.data.item
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
   * Roles
   */
  role: id => {
    return apiCall.get(`config/role/${id}`).then(response => {
      return response.data.item
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
   * Domains
   */
  domains: params => {
    return apiCall.get('config/domains', { params }).then(response => {
      return response.data
    })
  },
  domain: id => {
    return apiCall.get(`config/domain/${id}`).then(response => {
      return response.data.item
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
   * Realms
   */
  realms: params => {
    return apiCall.get('config/realms', { params }).then(response => {
      return response.data
    })
  },
  realm: id => {
    return apiCall.get(`config/realm/${id}`).then(response => {
      return response.data.item
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
   * Floating Devices
   */
  floatingDevice: id => {
    return apiCall.get(`config/floating_device/${id}`).then(response => {
      return response.data.item
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
  /**
   * Switches
   */
  switches: params => {
    return apiCall.get(`config/switches`, { params }).then(response => {
      return response.data
    })
  },
  switche: id => {
    return apiCall.get(`config/switch/${id}`).then(response => {
      return response.data.item
    })
  },
  createSwitch: data => {
    return apiCall.post('config/switches', data).then(response => {
      return response.data
    })
  },
  updateSwitch: data => {
    return apiCall.patch(`config/switch/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteSwitch: id => {
    return apiCall.delete(`config/switch/${id}`)
  },
  /**
   * SwitchGroups
   */
  switchGroups: params => {
    return apiCall.get(`config/switch_groups`, { params }).then(response => {
      return response.data
    })
  },
  switchGroup: id => {
    return apiCall.get(`config/switch_group/${id}`).then(response => {
      return response.data.item
    })
  },
  createSwitchGroup: data => {
    return apiCall.post('config/switch_groups', data).then(response => {
      return response.data
    })
  },
  updateSwitchGroup: data => {
    return apiCall.patch(`config/switch_group/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteSwitchGroup: id => {
    return apiCall.delete(`config/switch_group/${id}`)
  }
}
