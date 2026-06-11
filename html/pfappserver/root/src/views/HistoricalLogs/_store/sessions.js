/**
* "$_historical_logs" store module — clone of LiveLogs/_store/sessions.js
* minus the per-peer session machinery: a historical query needs no
* server-side session, each "Load more" fans out per peer inside the
* session module's loadMore action.
*/
import store from '@/store'
import { v4 as uuidv4 } from 'uuid'
import api from '../_api'
import SessionStore from './session'
import i18n from '@/utils/locale'

const state = () => {
  return {
    _lastSessionId: null,
    message: '',
    status: ''
  }
}

const getters = {
  isLoading: state => state.status === 'loading',
  sessions: state => {
    return (Object.keys(state) || []).filter(key => {
      let [, namespace] = /^([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})$/.exec(key) || []
      return namespace
    }).map(namespace => store.getters[`$_historical_logs/${namespace}/session`])
  }
}

const actions = {
  optionsSession: ({ commit }) => {
    commit('LOG_SESSION_REQUEST')
    return api.options().then(response => {
      commit('LOG_SESSION_SUCCESS')
      return response
    }).catch(err => {
      commit('LOG_SESSION_ERROR', err.response)
      return err
    })
  },
  createSession: ({ commit }, form) => {
    commit('LOG_SESSION_REQUEST')
    const session_id = uuidv4()
    commit('LOG_SESSION_START', { form, session_id })
    return Promise.resolve({ session_id })
  },
  destroySession: ({ commit }, id) => {
    commit('LOG_SESSION_STOP', id)
  }
}

const mutations = {
  LOG_SESSION_REQUEST: state => { state.status = 'loading'; state.message = '' },
  LOG_SESSION_START: (state, { form, session_id }) => {
    state.status = 'success'
    const nameFromFiles = (files) => {
      let name = files[0].split('/').reverse()[0]
      if (files.length > 1) name += `...(+${files.length - 1} ${i18n.t('more')})`
      return name
    }
    store.registerModule(['$_historical_logs', session_id], SessionStore)
    store.dispatch(`$_historical_logs/${session_id}/setSession`, {
      ...form,
      session_id,
      name: nameFromFiles(form.files)
    })
  },
  SET_LAST_SESSION: (state, id) => { state._lastSessionId = id },
  LOG_SESSION_STOP: (state, id) => {
    state.status = 'success'
    if (state._lastSessionId === id) state._lastSessionId = null
    setTimeout(() => store.unregisterModule(['$_historical_logs', id]), 300)
  },
  LOG_SESSION_SUCCESS: state => { state.status = 'success' },
  LOG_SESSION_ERROR: (state, response) => {
    state.status = 'error'
    if (response && response.data) state.message = response.data.message
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
