import apiCall from '@/utils/api'

export default {
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
