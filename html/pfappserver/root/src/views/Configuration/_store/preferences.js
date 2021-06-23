import { customRef } from '@vue/composition-api'
import { defineStore } from 'pinia'
import store from '@/store' // required for 'system/version'
import apiCall from '@/utils/api'

export const IDENTIFIER_PREFIX = 'pfappserver::' // transparently prefix all identifiers - avoid key collisions

export const api = {
  getPreference: id => {
    return apiCall.getQuiet(`preference/${IDENTIFIER_PREFIX}${id}`).then(response => {
      const { data } = JSON.parse(response.data.item.value)
      return data
    })
  },
  setPreference: (id, data) => {
    if (data) {
      let body = {
        id: `${IDENTIFIER_PREFIX}${id}`,
        value: JSON.stringify({
          data,
          meta: {
            created_at: (new Date()).getTime(),
            updated_at: (new Date()).getTime(),
            version: store.getters['system/version']
          }
        })
      }
      return apiCall.getQuiet(['preference', `${IDENTIFIER_PREFIX}${id}`]).then(response => { // exists
        const { data: { item: { value = null } = {} } = {} } = response
        if (value) {
          const { meta: { created_at = null } = {} } = JSON.parse(value)
          if (created_at) { // retain `created_at`
            body = {
              id: `${IDENTIFIER_PREFIX}${id}`,
              value: JSON.stringify({
                data,
                meta: {
                  created_at: created_at,
                  updated_at: (new Date()).getTime(),
                  version: store.getters['system/version']
                }
              })
            }
          }
        }
        return apiCall.putQuiet(['preference', `${IDENTIFIER_PREFIX}${id}`], body).then(response => {
          return response.data
        })
      }).catch(() => { // not exists
        return apiCall.putQuiet(['preference', `${IDENTIFIER_PREFIX}${id}`], body).then(response => {
          return response.data
        })
      })
    }
    else {
      return apiCall.deleteQuiet(['preference', `${IDENTIFIER_PREFIX}${id}`]).then(response => {
        return response
      })
    }
  },
  removePreference: id => {
    return apiCall.deleteQuiet(['preference', `${IDENTIFIER_PREFIX}${id}`]).then(response => {
      return response
    })
  }
}

export const useStore = defineStore({
  id: 'preferences',
  state() {
    return {
      cache: {}
    }
  },
  getters: {},
  actions: {
    getItem(id, defaultValue) {
      if (!(id in this.cache))
        this.cache[id] = undefined
      return api.getPreference(id)
        .then(item => { // exists
          this.cache[id] = item
          return this.cache[id]
        })
        .catch(() => { // not exists
          if (defaultValue !== undefined)
            return this.setItem(id, defaultValue)
          else
            return this.cache[id]
        })
    },
    setItem(id, value) {
      if (JSON.stringify(value) === JSON.stringify(this.cache[id]))
        return Promise.resolve(this.cache[id])
      if (value === undefined) {
        return api.removePreference(id).then(() => {
          this.cache[id] = undefined
          return this.cache[id]
        })
      }
      else {
        return api.setPreference(id, value).then(() => {
          this.cache[id] = value
          return this.cache[id]
        })
      }
    },
    reset() {
      this.cache = {}
    }
  }
})

export const usePreference = (key, defaultValue) => {
  const {
    getItem,
    setItem
  } = useStore()
  return customRef((track, trigger) => ({
    get() {
      track()
      return getItem(key, defaultValue)
    },
    set(newValue) {
      return setItem(key, newValue)
        .finally(() => trigger())
    }
  }))
}
