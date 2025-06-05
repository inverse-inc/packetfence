import Vue from 'vue'
import { types } from '@/store'
import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_connectors/isDomainLoading']),
    getList: () => $store.dispatch('$_connectors/allDomains'),
    getListOptions: () => $store.dispatch('$_connectors/optionsDomains'),
    sortItems: params => $store.dispatch('$_connectors/sortDomains', params.items),
    createItem: params => $store.dispatch('$_connectors/createDomain', params),
    getItem: params => $store.dispatch('$_connectors/getDomain', params.id).then(item => {
      return (params.isClone)
        ? { ...item, id: `${item.id}-${i18n.t('copy')}`, not_deletable: false }
        : item
    }),
    getItemOptions: params => $store.dispatch('$_connectors/optionsDomains', params.id),
    updateItem: params => $store.dispatch('$_connectors/updateDomain', params),
    deleteItem: params => $store.dispatch('$_connectors/deleteDomain', params.id),
  }
}

// Default values
export const state = () => {
  return {
    dnCache: {}, // items details
    dnMessage: '',
    dnStatus: ''
  }
}

export const getters = {
  isDomainWaiting: state => [types.LOADING, types.DELETING].includes(state.dnStatus),
  isDomainLoading: state => state.dnStatus === types.LOADING
}

export const actions = {
  allDomains: () => {
    const params = {
      sort: 'id',
      fields: ['id', 'description'].join(',')
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  optionsDomains: ({ commit }, id) => {
    commit('DOMAIN_ITEM_REQUEST')
    if (id) {
      return api.itemOptions(id).then(response => {
        commit('DOMAIN_ITEM_SUCCESS')
        return response
      }).catch((err) => {
        commit('DOMAIN_ITEM_ERROR', err.response)
        throw err
      })
    } else {
      return api.listOptions().then(response => {
        commit('DOMAIN_ITEM_SUCCESS')
        return response
      }).catch((err) => {
        commit('DOMAIN_ITEM_ERROR', err.response)
        throw err
      })
    }
  },
  getDomain: ({ state, commit }, id) => {
    if (state.dnCache[id]) {
      return Promise.resolve(state.dnCache[id]).then(dnCache => JSON.parse(JSON.stringify(dnCache)))
    }
    commit('DOMAIN_ITEM_REQUEST')
    return api.item(id).then(item => {
      commit('DOMAIN_ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('DOMAIN_ITEM_ERROR', err.response)
      throw err
    })
  },
  createDomain: ({ commit }, data) => {
    commit('DOMAIN_ITEM_REQUEST')
    return api.create(data).then(response => {
      commit('DOMAIN_ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('DOMAIN_ITEM_ERROR', err.response)
      throw err
    })
  },
  updateDomain: ({ commit }, data) => {
    commit('DOMAIN_ITEM_REQUEST')
    return api.update(data).then(response => {
      commit('DOMAIN_ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('DOMAIN_ITEM_ERROR', err.response)
      throw err
    })
  },
  sortDomains: ({ commit }, data) => {
    const params = {
      items: data
    }
    commit('DOMAIN_ITEM_REQUEST', types.LOADING)
    return api.sort(params).then(response => {
      commit('DOMAIN_ITEM_SUCCESS')
      return response
    }).catch(err => {
      commit('DOMAIN_ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteDomain: ({ commit }, id) => {
    commit('DOMAIN_ITEM_REQUEST', types.DELETING)
    return api.delete(id).then(response => {
      commit('DOMAIN_ITEM_DESTROYED', id)
      return response
    }).catch(err => {
      commit('DOMAIN_ITEM_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  DOMAIN_ITEM_REQUEST: (state, type) => {
    state.dnStatus = type || types.LOADING
    state.dnMessage = ''
  },
  DOMAIN_ITEM_REPLACED: (state, data) => {
    state.dnStatus = types.SUCCESS
    Vue.set(state.dnCache, data.id, JSON.parse(JSON.stringify(data)))
  },
  DOMAIN_ITEM_DESTROYED: (state, id) => {
    state.dnStatus = types.SUCCESS
    Vue.set(state.dnCache, id, null)
  },
  DOMAIN_ITEM_ERROR: (state, response) => {
    state.dnStatus = types.ERROR
    if (response && response.data) {
      state.dnMessage = response.data.message
    }
  },
  DOMAIN_ITEM_SUCCESS: (state) => {
    state.dnStatus = types.SUCCESS
  }
}
