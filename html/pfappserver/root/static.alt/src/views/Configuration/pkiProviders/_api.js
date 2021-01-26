import apiCall from '@/utils/api'

export default {
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
  }
}
