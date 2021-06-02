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
    dhcpFingerprints: {
      cache: {},
      message: '',
      status: ''
    }
  }
}

export const getters = {
  isDhcpFingerprintsWaiting: state => [types.LOADING, types.DELETING].includes(state.dhcpFingerprints.status),
  isDhcpFingerprintsLoading: state => state.dhcpFingerprints.status === types.LOADING
}

export const actions = {
  dhcpFingerprints: () => {
    const params = {
      sort: 'id',
      fields: ['id'].join(',')
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  getDhcpFingerprint: ({ state, commit }, id) => {
    if (state.dhcpFingerprints.cache[id]) {
      return Promise.resolve(state.dhcpFingerprints.cache[id])
    }
    commit('DHCP_FINGERPRINT_REQUEST')
    return api.item(id).then(item => {
      commit('DHCP_FINGERPRINT_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch(err => {
      commit('DHCP_FINGERPRINT_ERROR', err.response)
      throw err
    })
  },
  createDhcpFingerprint: ({ commit }, data) => {
    commit('DHCP_FINGERPRINT_REQUEST')
    return api.create(data).then(response => {
      data.id = response.id
      commit('DHCP_FINGERPRINT_REPLACED', data)
      return response
    }).catch(err => {
      commit('DHCP_FINGERPRINT_ERROR', err.response)
      throw err
    })
  },
  updateDhcpFingerprint: ({ commit }, data) => {
    commit('DHCP_FINGERPRINT_REQUEST')
    return api.update(data).then(response => {
      commit('DHCP_FINGERPRINT_REPLACED', data)
      return response
    }).catch(err => {
      commit('DHCP_FINGERPRINT_ERROR', err.response)
      throw err
    })
  },
  deleteDhcpFingerprint: ({ commit }, data) => {
    commit('DHCP_FINGERPRINT_REQUEST', types.DELETING)
    return api.delete(data).then(response => {
      commit('DHCP_FINGERPRINT_DESTROYED', data)
      return response
    }).catch(err => {
      commit('DHCP_FINGERPRINT_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  DHCP_FINGERPRINT_REQUEST: (state, type) => {
    state.dhcpFingerprints.status = type || types.LOADING
    state.dhcpFingerprints.message = ''
  },
  DHCP_FINGERPRINT_REPLACED: (state, data) => {
    state.dhcpFingerprints.status = types.SUCCESS
    Vue.set(state.dhcpFingerprints.cache, data.id, data)
  },
  DHCP_FINGERPRINT_DESTROYED: (state, id) => {
    state.dhcpFingerprints.status = types.SUCCESS
    Vue.set(state.dhcpFingerprints.cache, id, null)
  },
  DHCP_FINGERPRINT_ERROR: (state, response) => {
    state.dhcpFingerprints.status = types.ERROR
    if (response && response.data) {
      state.dhcpFingerprints.message = response.data.message
    }
  }
}
