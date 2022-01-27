/**
* "pfqueue" store module
*/
import Vue from 'vue'
import { types } from '@/store'
import apiCall from '@/utils/api'

const retries = {} // global retry counter

const pollTaskStatus = ({ task_id, headers }) => {
  return apiCall.getQuiet(`pfqueue/task/${task_id}/status/poll`, { headers }).then(response => {
    if (task_id in retries)
      delete retries[task_id]
    return response.data
  }).catch(error => {
    if (error.response && error.code !== 'ERR_NETWORK') { // The request was made and a response with a status code was received
      throw error
    }
    else {
      if (!(id in retries))
        retries[id] = 0
      else
        retries[id]++
      if (retries[id] > 10) // give up after N retries
        throw error
      return new Promise((resolve, reject) => {
        setTimeout(() => { // debounce retries
          pollTaskStatus({ task_id, headers })
            .then(resolve)
            .catch(reject)
        }, 1000)
      })
    }
  })
}

const api = {
  getStats: () => {
    return apiCall.getQuiet(`queues/stats`).then(response => {
      return response.data.items
    })
  },
  pollTaskStatus
}

// Default values
const initialState = () => {
  return {
    stats: false,
    tasks: false,
    message: '',
    requestStatus: ''
  }
}

const getters = {
  isLoading: state => state.requestStatus === types.LOADING,
  stats: state => state.stats || []
}

const actions = {
  getStats: ({ commit, state }) => {
    commit('PFQUEUE_REQUEST')
    return new Promise((resolve, reject) => {
      api.getStats().then(data => {
        commit('PFQUEUE_SUCCESS', data)
        resolve(state.stats)
      }).catch(err => {
        commit('PFQUEUE_ERROR', err.response)
        reject(err)
      })
    })
  },
  pollTaskStatus: ({ dispatch }, { task_id, headers }) => {
    return api.pollTaskStatus({ task_id, headers }).then(data => { // 'poll' returns immediately, or timeout after 15s
      if ('status' in data && data.status.toString() === '202') { // 202: in progress
        return dispatch('pollTaskStatus', { task_id, headers }) // recurse
      }
      if ('error' in data) {
        throw new Error(data.error.message)
      }
      return data.item
    }).catch(error => {
      throw error
    })
  }
}

const mutations = {
  PFQUEUE_REQUEST: (state) => {
    state.requestStatus = types.LOADING
    state.message = ''
  },
  PFQUEUE_SUCCESS: (state, data) => {
    Vue.set(state, 'stats', data)
    state.requestStatus = types.SUCCESS
    state.message = ''
  },
  PFQUEUE_ERROR: (state, data) => {
    state.requestStatus = types.ERROR
    const { response: { data: { message } = {} } = {} } = data
    if (message) {
      state.message = message
    }
  },
  $RESET: (state) => {
    // eslint-disable-next-line no-unused-vars
    state = initialState()
  }
}

export default {
  namespaced: true,
  state: initialState(),
  getters,
  actions,
  mutations
}
