import apiCall from '@/utils/api'
import {
  decomposeCa,
  recomposeCa
} from './config'

export default {
  list: params => {
    return apiCall.getQuiet('pki/cas', { params }).then(response => {
      const { data: { items, ...rest } = {} } = response
      return { items: (items || []).map(item => decomposeCa(item)), ...rest }
    })
  },
  search: params => {
    return apiCall.postQuiet('pki/cas/search', params).then(response => {
      const { data: { items, ...rest } } = response
      return { items: (items || []).map(item => decomposeCa(item)), ...rest }
    })
  },
  create: data => {
    const { id, ...rest } = data // strip `id` from isClone
    return apiCall.post('pki/cas', recomposeCa(rest)).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return { id, ...decomposeCa(item) }
      }
    })
  },
  item: id => {
    return apiCall.get(['pki', 'ca', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return { id, ...decomposeCa(item) }
    })
  },
  update: data => {
    const { id, ...rest } = data
    return apiCall.patch(['pki', 'ca', id], recomposeCa(rest)).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return { id, ...decomposeCa(item) }
      }
    })
  },
  resign: data => {
    const { id, ...rest } = data
    return apiCall.post(['pki', 'ca', 'resign', id], recomposeCa(rest)).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return { id, ...decomposeCa(item) }
      }
    })
  },
  csr: data => {
    const { id, ...rest } = data
    return apiCall.post(['pki', 'ca', 'csr', id], recomposeCa(rest)).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return decomposeCa(item)
      }
    })
  }
}
