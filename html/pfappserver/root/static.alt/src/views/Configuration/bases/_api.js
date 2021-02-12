import apiCall from '@/utils/api'

export default {
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
  }
}
