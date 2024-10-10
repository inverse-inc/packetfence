import apiCall from '@/utils/api'
import {
  decomposeProfile,
  recomposeProfile
} from './config'

export default {
  list: params => {
    return apiCall.getQuiet('pki/profiles', { params }).then(response => {
      const { data: { items, ...rest } = {} } = response
      return { items: (items || []).map(item => decomposeProfile(item)), ...rest }
    })
  },
  search: params => {
    return apiCall.postQuiet('pki/profiles/search', params).then(response => {
      const { data: { items, ...rest } } = response
      return { items: (items || []).map(item => decomposeProfile(item)), ...rest }
    })
  },
  create: data => {
    const { id, ...rest } = data // strip `id`
    return apiCall.post('pki/profiles', recomposeProfile(rest)).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return decomposeProfile(item)
      }
    })
  },
  item: id => {
    return apiCall.get(['pki', 'profile', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return { id, ...decomposeProfile(item) }
    })
  },
  update: data => {
    const { id, ...rest } = data
    return apiCall.patch(['pki', 'profile', id], recomposeProfile(rest)).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return { id, ...decomposeProfile(item) }
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
      return { id, ...decomposeProfile(item) }
    })
  }
}
