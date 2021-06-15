import Vue from 'vue'
import { computed } from '@vue/composition-api'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_fingerbank/isDhcpv6EnterprisesLoading']),
    createItem: params => $store.dispatch('$_fingerbank/createDhcpv6Enterprise', params),
    getItem: params => $store.dispatch('$_fingerbank/getDhcpv6Enterprise', params.id),
    updateItem: params => $store.dispatch('$_fingerbank/updateDhcpv6Enterprise', params),
    deleteItem: params => $store.dispatch('$_fingerbank/deleteDhcpv6Enterprise', params.id),
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
    dhcpv6Enterprises: {
      cache: {},
      message: '',
      status: ''
    }
  }
}

export const getters = {
  isDhcpv6EnterprisesWaiting: state => [types.LOADING, types.DELETING].includes(state.dhcpv6Enterprises.status),
  isDhcpv6EnterprisesLoading: state => state.dhcpv6Enterprises.status === types.LOADING
}

export const actions = {
  dhcpv6Enterprises: () => {
    const params = {
      sort: 'id',
      fields: ['id'].join(',')
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  getDhcpv6Enterprise: ({ state, commit }, id) => {
    if (state.dhcpv6Enterprises.cache[id]) {
      return Promise.resolve(state.dhcpv6Enterprises.cache[id])
    }
    commit('DHCPV6_ENTERPRISE_REQUEST')
    return api.item(id).then(item => {
      commit('DHCPV6_ENTERPRISE_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch(err => {
      commit('DHCPV6_ENTERPRISE_ERROR', err.response)
      throw err
    })
  },
  createDhcpv6Enterprise: ({ commit }, data) => {
    commit('DHCPV6_ENTERPRISE_REQUEST')
    return api.create(data).then(response => {
      data.id = response.id
      commit('DHCPV6_ENTERPRISE_REPLACED', data)
      return response
    }).catch(err => {
      commit('DHCPV6_ENTERPRISE_ERROR', err.response)
      throw err
    })
  },
  updateDhcpv6Enterprise: ({ commit }, data) => {
    commit('DHCPV6_ENTERPRISE_REQUEST')
    return api.update(data).then(response => {
      commit('DHCPV6_ENTERPRISE_REPLACED', data)
      return response
    }).catch(err => {
      commit('DHCPV6_ENTERPRISE_ERROR', err.response)
      throw err
    })
  },
  deleteDhcpv6Enterprise: ({ commit }, data) => {
    commit('DHCPV6_ENTERPRISE_REQUEST', types.DELETING)
    return api.delete(data).then(response => {
      commit('DHCPV6_ENTERPRISE_DESTROYED', data)
      return response
    }).catch(err => {
      commit('DHCPV6_ENTERPRISE_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  DHCPV6_ENTERPRISE_REQUEST: (state, type) => {
    state.dhcpv6Enterprises.status = type || types.LOADING
    state.dhcpv6Enterprises.message = ''
  },
  DHCPV6_ENTERPRISE_REPLACED: (state, data) => {
    state.dhcpv6Enterprises.status = types.SUCCESS
    Vue.set(state.dhcpv6Enterprises.cache, data.id, data)
  },
  DHCPV6_ENTERPRISE_DESTROYED: (state, id) => {
    state.dhcpv6Enterprises.status = types.SUCCESS
    Vue.set(state.dhcpv6Enterprises.cache, id, null)
  },
  DHCPV6_ENTERPRISE_ERROR: (state, response) => {
    state.dhcpv6Enterprises.status = types.ERROR
    if (response && response.data) {
      state.dhcpv6Enterprises.message = response.data.message
    }
  }
}
