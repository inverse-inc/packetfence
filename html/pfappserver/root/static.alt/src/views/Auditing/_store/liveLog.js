/**
* "$_live_log" store module
*/
import Vue from 'vue'
import api from '../_api'

// Default values
const state = () => {
  return {
    session: {},
    message: '',
    itemStatus: ''
  }
}

const getters = {
  isLoading: state => state.itemStatus === 'loading',
  session: state => state.session
}

const actions = {
  setSession: ({ commit }, session) => {
    commit('SET_SESSION', session)
  }
}

const mutations = {
  SET_SESSION: (state, session) => {
    state.session = session
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}

