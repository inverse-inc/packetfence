import apiCall from '@/utils/api'
import {
  decomposeScepServer,
  recomposeScepServer
} from './config'

export default {
  list: params => {
    return apiCall.getQuiet('pki/scepservers', { params }).then(response => {
      const { data: { items, ...rest } = {} } = response
      return { items: (items || []).map(item => decomposeScepServer(item)), ...rest }
    })
  },
  search: params => {
    return apiCall.postQuiet('pki/scepserver/search', params).then(response => {
      const { data: { items, ...rest } } = response
      return { items: (items || []).map(item => decomposeScepServer(item)), ...rest }
    })
  },
  create: data => {
    const { id, ...rest } = data // strip `id` from isClone
    return apiCall.post('pki/scepserver', recomposeScepServer(rest)).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return { id, ...decomposeScepServer(item) }
      }
    })
  },
  item: id => {
    return apiCall.get(['pki', 'scepserver', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return { id, ...decomposeScepServer(item) }
    })
  },
}
