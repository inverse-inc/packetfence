import apiCall from '@/utils/api'

export default {
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
  }
}
