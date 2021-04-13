
/**
 * "notification" store module
 */
// import Vue from 'vue'
import uuidv4 from 'uuid/v4'

const initialState = () => {
  return {
    all: [],
    hideDelay: 5
  }
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
    commit('NOTIFICATION', { base: notification, data, commit })
  },
  warning: ({ commit }, data) => {
    let notification = {
      variant: 'warning',
      icon: 'exclamation-triangle',
      new: true,
      unread: true,
      timestamp: new Date()
    }
    commit('NOTIFICATION', { base: notification, data, commit })
  },
  danger: ({ commit }, data) => {
    let notification = {
      variant: 'danger',
      icon: 'ban',
      new: true,
      unread: true,
      timestamp: new Date()
    }
    commit('NOTIFICATION', { base: notification, data, commit })
  },
  status_success: ({ commit }, data) => {
    let notification = {
      variant: 'success',
      icon: 'check',
      new: true,
      unread: true,
      timestamp: new Date()
    }
    commit('NOTIFICATION', { base: notification, data, commit })
  },
  status_skipped: ({ commit }, data) => {
    let notification = {
      variant: 'warning',
      icon: 'exclamation-circle',
      new: true,
      unread: true,
      timestamp: new Date()
    }
    commit('NOTIFICATION', { base: notification, data, commit })
  },
  status_failed: ({ commit }, data) => {
    let notification = {
      variant: 'danger',
      icon: 'ban',
      new: true,
      unread: true,
      timestamp: new Date()
    }
    commit('NOTIFICATION', { base: notification, data, commit })
  }
}

const mutations = {
  NOTIFICATION: (state, params) => {
    const { base, data, commit } = params
    let notification
    if (typeof data === 'string') {
      notification = Object.assign(base, { message: data })
    } else if (data.message) {
      notification = Object.assign(base, data)
    }
    if (notification) {
      notification.id = uuidv4()
      state.all.splice(0, 0, notification)
      setTimeout(() => {
        commit('NOTIFICATION_UNMARK_NEW', notification)
      }, state.hideDelay * 1000)
    }
  },
  NOTIFICATION_UNMARK_NEW: (state, notification) => {
    notification.new = false
  },
  NOTIFICATION_UNMARK_UNREAD: (state, notification) => {
    notification.unread = false
  },
  NOTIFICATION_DISMISS: (state, notification) => {
    notification.new = notification.unread = false
  },
  $RESET: (state) => {
    const newState = initialState()
    for (const key of Object.keys(newState)) { // preserve reactivity
      state[key] = newState[key]
    }
  }
}

export default {
  namespaced: true,
  state: initialState(),
  getters,
  actions,
  mutations
}
