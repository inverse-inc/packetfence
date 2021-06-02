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
    combinations: {
      cache: {},
      message: '',
      status: ''
    }
  }
}

export const getters = {
  isCombinationsWaiting: state => [types.LOADING, types.DELETING].includes(state.combinations.status),
  isCombinationsLoading: state => state.combinations.status === types.LOADING,
}

export const actions = {
  combinations: () => {
    const params = {
      sort: 'id',
      fields: ['id'].join(',')
    }
    return api.list(params).then(response => {
      return response.items
    })
  },
  getCombination: ({ state, commit }, id) => {
    if (state.combinations.cache[id]) {
      return Promise.resolve(state.combinations.cache[id])
    }
    commit('COMBINATION_REQUEST')
    return api.item(id).then(item => {
      commit('COMBINATION_REPLACED', item)
      return JSON.parse(JSON.stringify(item))
    }).catch(err => {
      commit('COMBINATION_ERROR', err.response)
      throw err
    })
  },
  createCombination: ({ commit }, data) => {
    commit('COMBINATION_REQUEST')
    return api.create(data).then(response => {
      data.id = response.id
      commit('COMBINATION_REPLACED', data)
      return response
    }).catch(err => {
      commit('COMBINATION_ERROR', err.response)
      throw err
    })
  },
  updateCombination: ({ commit }, data) => {
    commit('COMBINATION_REQUEST')
    return api.update(data).then(response => {
      commit('COMBINATION_REPLACED', data)
      return response
    }).catch(err => {
      commit('COMBINATION_ERROR', err.response)
      throw err
    })
  },
  deleteCombination: ({ commit }, data) => {
    commit('COMBINATION_REQUEST', types.DELETING)
    return api.delete(data).then(response => {
      commit('COMBINATION_DESTROYED', data)
      return response
    }).catch(err => {
      commit('COMBINATION_ERROR', err.response)
      throw err
    })
  }
}

export const mutations = {
  COMBINATION_REQUEST: (state, type) => {
    state.combinations.status = type || types.LOADING
    state.combinations.message = ''
  },
  COMBINATION_REPLACED: (state, data) => {
    state.combinations.status = types.SUCCESS
    Vue.set(state.combinations.cache, data.id, data)
  },
  COMBINATION_DESTROYED: (state, id) => {
    state.combinations.status = types.SUCCESS
    Vue.set(state.combinations.cache, id, null)
  },
  COMBINATION_ERROR: (state, response) => {
    state.combinations.status = types.ERROR
    if (response && response.data) {
      state.combinations.message = response.data.message
    }
  },
  COMBINATION_SUCCESS: (state) => {
    state.combinations.status = types.SUCCESS
  }
}
