import apiCall from '@/utils/api'
import {
  decomposeHsm,
  recomposeHsm
} from './config'

export default {
  list: params => {
    return apiCall.getQuiet('pki/hsms', { params }).then(response => {
      const { data: { items, ...rest } = {} } = response
      return { items: (items || []).map(item => decomposeHsm(item)), ...rest }
    })
  },
  search: params => {
    return apiCall.postQuiet('pki/hsms/search', params).then(response => {
      const { data: { items, ...rest } } = response
      return { items: (items || []).map(item => decomposeHsm(item)), ...rest }
    })
  },
  create: data => {
    const { id, ...rest } = data // strip `id`
    return apiCall.post('pki/hsms', recomposeHsm(rest)).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return { id, ...decomposeHsm(item) }
      }
    })
  },
  item: id => {
    return apiCall.get(['pki', 'hsm', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return { id, ...decomposeHsm(item) }
    })
  },
  update: data => {
    const { id, ...rest } = data // strip `id`
    return apiCall.patch(['pki', 'hsm', id], recomposeHsm(rest)).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return { id, ...decomposeHsm(item) }
      }
    })
  },
  delete: id => {
    return apiCall.delete(['pki', 'hsm', id])
  }
}
