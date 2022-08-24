import apiCall from '@/utils/api'
import { recomposeGorm } from '../config'

export default {
  list: params => {
    return apiCall.getQuiet('pki/profiles', { params }).then(response => {
      const { data: { items = [], ...rest } = {} } = response
      return { items: items.map(item => recomposeGorm(item)), ...rest }
    })
  },
  search: params => {
    return apiCall.postQuiet('pki/profiles/search', params).then(response => {
      const { data: { items = [], ...rest } } = response
      return { items: items.map(item => recomposeGorm(item)), ...rest }
    })
  },
  create: data => {
    const { id, ...rest } = data // strip `id` from isClone
    return apiCall.post('pki/profiles', rest).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return recomposeGorm(item)
      }
    })
  },
  item: id => {
    return apiCall.get(['pki', 'profile', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return recomposeGorm(item)
    })
  },
  update: data => {
    const { id, ...rest } = data
    return apiCall.patch(['pki', 'profile', id], rest).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return recomposeGorm(item)
      }
    })
  },
  delete: id => {
    return apiCall.delete(['pki', 'profile', id])
  },
  signCsr: data => {
    const { id, csr } = data
    return apiCall.post(['pki', 'profile', id, 'sign_csr'], { csr }).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return recomposeGorm(item)
    })
  }
}
