import apiCall from '@/utils/api'

export default {
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
  }
}
