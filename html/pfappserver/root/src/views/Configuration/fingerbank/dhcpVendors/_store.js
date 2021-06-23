import Vue from 'vue'
import { computed } from '@vue/composition-api'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_fingerbank/isDhcpVendorsLoading']),
    createItem: params => $store.dispatch('$_fingerbank/createDhcpVendor', params),
    getItem: params => $store.dispatch('$_fingerbank/getDhcpVendor', params.id),
    updateItem: params => $store.dispatch('$_fingerbank/updateDhcpVendor', params),
    deleteItem: params => $store.dispatch('$_fingerbank/deleteDhcpVendor', params.id),
  }
}

const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
export const state = () => {
  return {
    dhcpVendors: {
      cache: {},
      message: '',
      status: ''
    }
  }
}

export const getters = {
  isDhcpVendorsWaiting: state => [types.LOADING, types.DELETING].includes(state.dhcpVendors.status),
  isDhcpVendorsLoading: state => state.dhcpVendors.status === types.LOADING
}

export const actions = {
  dhcpVendors: () => {
    const params = {
      sort: 'id',
      fields: ['id'].join(',')
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  getDhcpVendor: ({ state, commit }, id) => {
    if (state.dhcpVendors.cache[id]) {
      return Promise.resolve(state.dhcpVendors.cache[id])
    }
    commit('DHCP_VENDOR_REQUEST')
    return api.item(id).then(item => {
      commit('DHCP_VENDOR_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch(err => {
      commit('DHCP_VENDOR_ERROR', err.response)
      throw err
    })
  },
  createDhcpVendor: ({ commit }, data) => {
    commit('DHCP_VENDOR_REQUEST')
    return api.create(data).then(response => {
      data.id = response.id
      commit('DHCP_VENDOR_REPLACED', data)
      return response
    }).catch(err => {
      commit('DHCP_VENDOR_ERROR', err.response)
      throw err
    })
  },
  updateDhcpVendor: ({ commit }, data) => {
    commit('DHCP_VENDOR_REQUEST')
    return api.update(data).then(response => {
      commit('DHCP_VENDOR_REPLACED', data)
      return response
    }).catch(err => {
      commit('DHCP_VENDOR_ERROR', err.response)
      throw err
    })
  },
  deleteDhcpVendor: ({ commit }, id) => {
    commit('DHCP_VENDOR_REQUEST', types.DELETING)
    return api.delete(id).then(response => {
      commit('DHCP_VENDOR_DESTROYED', id)
      return response
    }).catch(err => {
      commit('DHCP_VENDOR_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  DHCP_VENDOR_REQUEST: (state, type) => {
    state.dhcpFingerprints.status = type || types.LOADING
    state.dhcpVendors.message = ''
  },
  DHCP_VENDOR_REPLACED: (state, data) => {
    state.dhcpFingerprints.status = types.SUCCESS
    Vue.set(state.dhcpVendors.cache, data.id, data)
  },
  DHCP_VENDOR_DESTROYED: (state, id) => {
    state.dhcpFingerprints.status = types.SUCCESS
    Vue.set(state.dhcpVendors.cache, id, null)
  },
  DHCP_VENDOR_ERROR: (state, response) => {
    state.dhcpFingerprints.status = types.ERROR
    if (response && response.data) {
      state.dhcpVendors.message = response.data.message
    }
  }
}
