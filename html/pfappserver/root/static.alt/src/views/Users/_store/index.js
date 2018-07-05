/**
* "$_users" store module
*/
import Vue from 'vue'
import api from '../_api'

const STORAGE_SAVED_SEARCH = 'users-saved-search'

// Default values
const state = {
  items: {}, // users details
  message: '',
  userStatus: '',
  savedSearches: JSON.parse(localStorage.getItem(STORAGE_SAVED_SEARCH)) || []
}

const getters = {
  isLoading: state => state.userStatus === 'loading'
}

const actions = {
  addSavedSearch: ({commit}, search) => {
    let savedSearches = state.savedSearches
    savedSearches = state.savedSearches.filter(searches => searches.name !== search.name)
    savedSearches.push(search)
    savedSearches.sort((a, b) => {
      return a.name.localeCompare(b.name)
    })
    commit('SAVED_SEARCHES_UPDATED', savedSearches)
    localStorage.setItem(STORAGE_SAVED_SEARCH, JSON.stringify(savedSearches))
  },
  deleteSavedSearch: ({commit}, search) => {
    let savedSearches = state.savedSearches.filter(searches => searches.name !== search.name)
    commit('SAVED_SEARCHES_UPDATED', savedSearches)
    localStorage.setItem(STORAGE_SAVED_SEARCH, JSON.stringify(savedSearches))
  },
  getUser: ({commit, state}, pid) => {
    if (state.items[pid]) {
      return Promise.resolve(state.items[pid])
    }
    commit('USER_REQUEST')
    return api.user(pid).then(data => {
      commit('USER_REPLACED', data)
      return state.items[pid]
    }).catch(err => {
      commit('USER_ERROR', err.response)
      return err
    })
  },
  createUser: ({commit}, data) => {
    commit('USER_REQUEST')
    return new Promise((resolve, reject) => {
      api.createUser(data).then(response => {
        commit('USER_REPLACED', data)
        resolve(response)
      }).catch(err => {
        commit('USER_ERROR', err.response)
        reject(err)
      })
    })
  },
  updateUser: ({commit}, data) => {
    commit('USER_REQUEST')
    delete data.access_duration
    delete data.access_level
    return api.updateUser(data).then(response => {
      commit('USER_REPLACED', data)
      return response
    }).catch(err => {
      commit('USER_ERROR', err.response)
    })
  },
  deleteUser: ({commit}, pid) => {
    commit('USER_REQUEST')
    return new Promise((resolve, reject) => {
      api.deleteUser(pid).then(response => {
        commit('USER_DESTROYED', pid)
        resolve(response)
      }).catch(err => {
        commit('USER_ERROR', err.response)
        reject(err)
      })
    })
  }
}

const mutations = {
  USER_REQUEST: (state) => {
    state.userStatus = 'loading'
  },
  USER_REPLACED: (state, data) => {
    Vue.set(state.items, data.pid, data)
    // TODO: update items if found in it
    state.userStatus = 'success'
  },
  USER_DESTROYED: (state, pid) => {
    state.userStatus = 'success'
    Vue.set(state.items, pid, null)
  },
  USER_ERROR: (state, response) => {
    state.userStatus = 'error'
    if (response && response.data) {
      state.message = response.data.message
    }
  },
  SAVED_SEARCHES_UPDATED: (state, searches) => {
    state.savedSearches = searches
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
