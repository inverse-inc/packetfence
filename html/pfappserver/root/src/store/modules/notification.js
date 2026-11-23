
/**
 * "notification" store module
 */
// import Vue from 'vue'
import { v4 as uuidv4 } from 'uuid'

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
  // A notification of a task under way, updated in place by its key (data:
  // { key, message, progress (0-100), done, ok }): its toast stays, with a
  // progress bar, until it is done; then it shows the result and hides like
  // the others.
  progress: ({ state, commit }, { key, message, progress = 0, done = false, ok = true }) => {
    const variant = (!done) ? 'info' : ((ok) ? 'success' : 'danger')
    const icon = (!done) ? 'sync' : ((ok) ? 'check' : 'ban')
    const existing = state.all.find(notification => notification.key === key)
    if (existing)
      commit('NOTIFICATION_PROGRESS', { notification: existing, changes: { message, progress, variant, icon, persistent: !done, new: true, unread: true, timestamp: new Date() } })
    else
      commit('NOTIFICATION', { base: { variant, icon, new: true, unread: true, timestamp: new Date(), key, progress, persistent: !done }, data: { message }, commit })
    if (done) {
      const notification = state.all.find(n => n.key === key)
      setTimeout(() => {
        if (notification && !notification.persistent)
          commit('NOTIFICATION_UNMARK_NEW', notification)
      }, state.hideDelay * 1000)
    }
  },
  // The tasks whose key starts with prefix are no longer followed (eg the
  // plugin that started them is unmounted): their toasts hide, without a
  // progress bar.
  finishProgress: ({ state, commit }, prefix) => {
    state.all.filter(({ key, persistent }) => persistent && typeof key === 'string' && key.startsWith(prefix))
      .forEach(notification => commit('NOTIFICATION_PROGRESS', { notification, changes: { persistent: false, new: false, icon: 'info-circle' } }))
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
      const filtered = state.all.filter(({ message, url }) => {
        return message !== notification.message || url !== notification.url
      })
      if (state.all.length !== filtered.length) {
        state.all = filtered
      }
      notification.id = uuidv4()
      state.all.splice(0, 0, notification)
      setTimeout(() => {
        if (!notification.key) // a task (progress) hides once done, after its own delay
          commit('NOTIFICATION_UNMARK_NEW', notification)
      }, state.hideDelay * 1000)
    }
  },
  NOTIFICATION_PROGRESS: (state, { notification, changes }) => {
    Object.assign(notification, changes)
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
