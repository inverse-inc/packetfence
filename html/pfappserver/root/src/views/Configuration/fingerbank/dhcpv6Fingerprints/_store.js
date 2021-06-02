import Vue from 'vue'
import api from './_api'

const types = {
  LOADING: 'loading',
  DELETING: 'deleting',
  SUCCESS: 'success',
  ERROR: 'error'
}

// Default values
export const state = () => {
  return {
    dhcpv6Fingerprints: {
      cache: {},
      message: '',
      status: ''
    }
  }
}

export const getters = {
  isDhcpv6FingerprintsWaiting: state => [types.LOADING, types.DELETING].includes(state.dhcpv6Fingerprints.status),
  isDhcpv6FingerprintsLoading: state => state.dhcpv6Fingerprints.status === types.LOADING
}

export const actions = {
  dhcpv6Fingerprints: () => {
    const params = {
      sort: 'id',
      fields: ['id'].join(',')
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  getDhcpv6Fingerprint: ({ state, commit }, id) => {
    if (state.dhcpv6Fingerprints.cache[id]) {
      return Promise.resolve(state.dhcpv6Fingerprints.cache[id])
    }
    commit('DHCPV6_FINGERPRINT_REQUEST')
    return api.item(id).then(item => {
      commit('DHCPV6_FINGERPRINT_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch(err => {
      commit('DHCPV6_FINGERPRINT_ERROR', err.response)
      throw err
    })
  },
  createDhcpv6Fingerprint: ({ commit }, data) => {
    commit('DHCPV6_FINGERPRINT_REQUEST')
    return api.create(data).then(response => {
      data.id = response.id
      commit('DHCPV6_FINGERPRINT_REPLACED', data)
      return response
    }).catch(err => {
      commit('DHCPV6_FINGERPRINT_ERROR', err.response)
      throw err
    })
  },
  updateDhcpv6Fingerprint: ({ commit }, data) => {
    commit('DHCPV6_FINGERPRINT_REQUEST')
    return api.update(data).then(response => {
      commit('DHCPV6_FINGERPRINT_REPLACED', data)
      return response
    }).catch(err => {
      commit('DHCPV6_FINGERPRINT_ERROR', err.response)
      throw err
    })
  },
  deleteDhcpv6Fingerprint: ({ commit }, data) => {
    commit('DHCPV6_FINGERPRINT_REQUEST', types.DELETING)
    return api.delete(data).then(response => {
      commit('DHCPV6_FINGERPRINT_DESTROYED', data)
      return response
    }).catch(err => {
      commit('DHCPV6_FINGERPRINT_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  DHCPV6_FINGERPRINT_REQUEST: (state, type) => {
    state.dhcpv6Fingerprints.status = type || types.LOADING
    state.dhcpv6Fingerprints.message = ''
  },
  DHCPV6_FINGERPRINT_REPLACED: (state, data) => {
    state.dhcpv6Fingerprints.status = types.SUCCESS
    Vue.set(state.dhcpv6Fingerprints.cache, data.id, data)
  },
  DHCPV6_FINGERPRINT_DESTROYED: (state, id) => {
    state.dhcpv6Fingerprints.status = types.SUCCESS
    Vue.set(state.dhcpv6Fingerprints.cache, id, null)
  },
  DHCPV6_FINGERPRINT_ERROR: (state, response) => {
    state.dhcpv6Fingerprints.status = types.ERROR
    if (response && response.data) {
      state.dhcpv6Fingerprints.message = response.data.message
    }
  }
}
