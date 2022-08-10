import apiCall from '@/utils/api'
import { recomposeGorm } from '../config'

export default {
  list: params => {
    return apiCall.getQuiet('pki/cas', { params }).then(response => {
      const { data: { items = [] } = {} } = response
      return { items: items.map(item => recomposeGorm(item)) }
    })
  },
  search: params => {
    return apiCall.postQuiet('pki/cas/search', params).then(response => {
      const { data: { items = [] }, ...rest } = response
      return { items: items.map(item => recomposeGorm(item)), ...rest }
    })
  },
  create: data => {
    const { id, ...rest } = data // strip `id` from isClone
    return apiCall.post('pki/cas', rest).then(response => {
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
    return apiCall.get(['pki', 'ca', id]).then(response => {
      const { data: { items: { 0: item = {} } = {} } = {} } = response
      return recomposeGorm(item)
    })
  },
  resign: data => {
    const { id, ...rest } = data
    return apiCall.post(['pki', 'ca', 'resign', id], rest).then(response => {
      const { data: { error } = {} } = response
      if (error) {
        throw error
      } else {
        const { data: { items: { 0: item = {} } = {} } = {} } = response
        return recomposeGorm(item)
      }
    })
  }
}
