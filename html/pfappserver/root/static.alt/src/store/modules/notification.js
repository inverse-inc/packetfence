
/**
 * "notification" store module
 */
// import Vue from 'vue'
import uuidv4 from 'uuid/v4'

const state = {
  all: [],
  hideDelay: 5
}

const getters = {}

const actions = {
  // data is expected to be either a string or an object with a 'message' property
  info: ({ commit }, data) => {
    let notification = {
      variant: 'info',
      icon: 'info-circle',
      new: true,
      unread: true,
      timestamp: new Date()
    }
    commit('NOTIFICATION', { base: notification, data })
  },
  warning: ({ commit }, data) => {
    let notification = {
      variant: 'warning',
      icon: 'exclamation-triangle',
      new: true,
      unread: true,
      timestamp: new Date()
    }
    commit('NOTIFICATION', { base: notification, data })
  },
  danger: ({ commit }, data) => {
    let notification = {
      variant: 'danger',
      icon: 'ban',
      new: true,
      unread: true,
      timestamp: new Date()
    }
    commit('NOTIFICATION', { base: notification, data })
  },
  status_success: ({ commit }, data) => {
    let notification = {
      variant: 'success',
      icon: 'check',
      new: true,
      unread: true,
      timestamp: new Date()
    }
    commit('NOTIFICATION', { base: notification, data })
  },
  status_skipped: ({ commit }, data) => {
    let notification = {
      variant: 'warning',
      icon: 'exclamation-circle',
      new: true,
      unread: true,
      timestamp: new Date()
    }
    commit('NOTIFICATION', { base: notification, data })
  },
  status_failed: ({ commit }, data) => {
    let notification = {
      variant: 'danger',
      icon: 'ban',
      new: true,
      unread: true,
      timestamp: new Date()
    }
    commit('NOTIFICATION', { base: notification, data })
  }
}

const mutations = {
  NOTIFICATION: (state, params) => {
    let notification
    if (typeof params.data === 'string') {
      notification = Object.assign(params.base, { message: params.data })
    } else if (params.data.message) {
      notification = Object.assign(params.base, params.data)
    }
    if (notification) {
      notification.id = uuidv4()
      state.all.splice(0, 0, notification)
      setTimeout(() => {
        notification.new = false
      }, state.hideDelay * 1000)
    }
  },
  CLEAR: (state) => {
    state.all = []
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
