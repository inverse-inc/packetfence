/**
* "$_live_logs" store module
*/
import store from '@/store'
import api from '../_api'
import LiveLogStore from './liveLog'

// Default values
const state = () => {
  return {
    message: '',
    status: ''
  }
}

const getters = {
  isLoading: state => state.status === 'loading',
  sessions: state => {
    return (Object.keys(state) || []).filter(key => {
      let [ , namespace ] = /^([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})$/.exec(key) || []
      return namespace
    }).map(namespace => {
      return store.getters[`$_live_logs/${namespace}/session`]
    })
  }
}

const actions = {
  optionsSession: ({ commit }) => {
    commit('LOG_SESSION_REQUEST')
    return api.optionsLogTailSession().then(response => {
      commit('LOG_SESSION_SUCCESS')
      return response
    }).catch(err => {
      commit('LOG_SESSION_ERROR', err.response)
      return err
    })
  },
  createSession: ({ commit }, form) => {
    commit('LOG_SESSION_REQUEST')
    return api.createLogTailSession(form).then(response => {
      commit('LOG_SESSION_START', { form, response })
      return response
    }).catch(err => {
      commit('LOG_SESSION_ERROR', err.response)
      return err
    })
  },
  destroySession: ({ commit }, id) => {
    commit('LOG_SESSION_REQUEST')
    return api.deleteLogTailSession(id).then(response => {
      commit('LOG_SESSION_STOP', id)
      return response
    }).catch(err => {
      commit('LOG_SESSION_STOP', id)
      commit('LOG_SESSION_ERROR', err.response)
      return err
    })
  }
}

const mutations = {
  LOG_SESSION_REQUEST: (state) => {
    state.status = 'loading'
    state.message = ''
  },
  LOG_SESSION_START: (state, { form, response }) => {
    state.status = 'success'
    const { session_id } = response
    if (session_id) {
      store.registerModule(['$_live_logs', session_id], LiveLogStore)
      store.dispatch(`$_live_logs/${session_id}/setSession`, { ...form, session_id })
    }
  },
  LOG_SESSION_STOP: (state, id) => {
    state.status = 'success'
    store.unregisterModule(['$_live_logs', id])
  },
  LOG_SESSION_SUCCESS: (state) => {
    state.status = 'success'
  },
  LOG_SESSION_ERROR: (state, response) => {
    state.status = 'error'
    if (response && response.data) {
      state.message = response.data.message
    }
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
