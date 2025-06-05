import Vue from 'vue'
import { types } from '@/store'
import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from './_api'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_connectors/isDnLoading']),
    getList: () => $store.dispatch('$_connectors/allDns'),
    getListOptions: () => $store.dispatch('$_connectors/optionsDns'),
    sortItems: params => $store.dispatch('$_connectors/sortDns', params.items),
    createItem: params => $store.dispatch('$_connectors/createDn', params),
    getItem: params => $store.dispatch('$_connectors/getDn', params.id).then(item => {
      return (params.isClone)
        ? { ...item, id: `${item.id}-${i18n.t('copy')}`, not_deletable: false }
        : item
    }),
    getItemOptions: params => $store.dispatch('$_connectors/optionsDns', params.id),
    updateItem: params => $store.dispatch('$_connectors/updateDn', params),
    deleteItem: params => $store.dispatch('$_connectors/deleteDn', params.id),
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
  isDnWaiting: state => [types.LOADING, types.DELETING].includes(state.dnStatus),
  isDnLoading: state => state.dnStatus === types.LOADING
}

export const actions = {
  allDns: () => {
    const params = {
      sort: 'id',
      fields: ['id', 'description'].join(',')
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  optionsDns: ({ commit }, id) => {
    commit('DN_ITEM_REQUEST')
    if (id) {
      return api.itemOptions(id).then(response => {
        commit('DN_ITEM_SUCCESS')
        return response
      }).catch((err) => {
        commit('DN_ITEM_ERROR', err.response)
        throw err
      })
    } else {
      return api.listOptions().then(response => {
        commit('DN_ITEM_SUCCESS')
        return response
      }).catch((err) => {
        commit('DN_ITEM_ERROR', err.response)
        throw err
      })
    }
  },
  getDn: ({ state, commit }, id) => {
    if (state.dnCache[id]) {
      return Promise.resolve(state.dnCache[id]).then(dnCache => JSON.parse(JSON.stringify(dnCache)))
    }
    commit('DN_ITEM_REQUEST')
    return api.item(id).then(item => {
      commit('DN_ITEM_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch((err) => {
      commit('DN_ITEM_ERROR', err.response)
      throw err
    })
  },
  createDn: ({ commit }, data) => {
    commit('DN_ITEM_REQUEST')
    return api.create(data).then(response => {
      commit('DN_ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('DN_ITEM_ERROR', err.response)
      throw err
    })
  },
  updateDn: ({ commit }, data) => {
    commit('DN_ITEM_REQUEST')
    return api.update(data).then(response => {
      commit('DN_ITEM_REPLACED', data)
      return response
    }).catch(err => {
      commit('DN_ITEM_ERROR', err.response)
      throw err
    })
  },
  sortDns: ({ commit }, data) => {
    const params = {
      items: data
    }
    commit('DN_ITEM_REQUEST', types.LOADING)
    return api.sort(params).then(response => {
      commit('DN_ITEM_SUCCESS')
      return response
    }).catch(err => {
      commit('DN_ITEM_ERROR', err.response)
      throw err
    })
  },
  deleteDn: ({ commit }, id) => {
    commit('DN_ITEM_REQUEST', types.DELETING)
    return api.delete(id).then(response => {
      commit('DN_ITEM_DESTROYED', id)
      return response
    }).catch(err => {
      commit('DN_ITEM_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  DN_ITEM_REQUEST: (state, type) => {
    state.dnStatus = type || types.LOADING
    state.dnMessage = ''
  },
  DN_ITEM_REPLACED: (state, data) => {
    state.dnStatus = types.SUCCESS
    Vue.set(state.dnCache, data.id, JSON.parse(JSON.stringify(data)))
  },
  DN_ITEM_DESTROYED: (state, id) => {
    state.dnStatus = types.SUCCESS
    Vue.set(state.dnCache, id, null)
  },
  DN_ITEM_ERROR: (state, response) => {
    state.dnStatus = types.ERROR
    if (response && response.data) {
      state.dnMessage = response.data.message
    }
  },
  DN_ITEM_SUCCESS: (state) => {
    state.dnStatus = types.SUCCESS
  }
}
