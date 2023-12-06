import apiCall from '@/utils/api'
import { decomposeRevokedCert } from './config'

export default {
  list: params => {
    return apiCall.getQuiet('pki/revokedcerts', { params }).then(response => {
      const { data: { items, ...rest } = {} } = response
      return { items: (items || []).map(item => decomposeRevokedCert(item)), ...rest }
    })
  },
  search: params => {
    return apiCall.postQuiet('pki/revokedcerts/search', params).then(response => {
      const { data: { items, ...rest } } = response
      return { items: (items || []).map(item => decomposeRevokedCert(item)), ...rest }
    })
  },
  item: id => {
    return apiCall.get(['pki', 'revokedcert', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return { id, ...decomposeRevokedCert(item) }
    })
  }
}
