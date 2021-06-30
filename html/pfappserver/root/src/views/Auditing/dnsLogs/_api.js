import Vue from 'vue'
import store from '@/store'
import apiCall from '@/utils/api'

export default {
  list: params => {
    return apiCall.get('dns_audit_logs', { params }).then(response => {
      return response.data
    })
  },
  search: body => {
    return apiCall.post('dns_audit_logs/search', body).then(response => {
      return response.data
    })
  },
  item: id => {
    return apiCall.get(`dns_audit_log/${id}`).then(response => {
      return response.data.item
    })
  },
  setPassthroughs: passthroughs => {
    return apiCall.patch('config/base/fencing', { passthroughs: passthroughs.join(',') }).then(response => {
      // Clear cached values
      Vue.set(store.state.config, 'baseFencing', false)
      if (store.state.$_bases) {
        Vue.set(store.state.$_bases.cache, 'fencing', false)
      }
      return response
    })
  }
}