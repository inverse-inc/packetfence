import apiCall from '@/utils/api'
import { recomposeGorm } from '../config'

export default {
  list: params => {
    return apiCall.getQuiet('pki/certs', { params }).then(response => {
      const { data: { items = [] } = {} } = response
      return { items: items.map(item => recomposeGorm(item)) }
    })
  },
  search: params => {
    return apiCall.postQuiet('pki/certs/search', params).then(response => {
      const { data: { items = [] }, ...rest } = response
      return { items: items.map(item => recomposeGorm(item)), ...rest }
    })
  },
  create: data => {
    const { id, ...rest } = data // strip `id` from isClone
    return apiCall.post('pki/certs', rest).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return recomposeGorm(item)
      }
    })
  },
  download: data => {
    const { id, password } = data
    return apiCall.getArrayBuffer(['pki', 'cert', id, 'download', password]).then(response => {
      const { data, data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        return data
      }
    })
  },
  item: id => {
    return apiCall.get(['pki', 'cert', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return recomposeGorm(item)
    })
  },
  email: id => {
    return apiCall.get(['pki', 'cert', id, 'email']).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { password } = {} } = response
        return { password }
      }
    })
  },
  revoke: data => {
    return apiCall.delete(['pki', 'cert', data.id, data.reason]).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        return true
      }
    })
  }
}
