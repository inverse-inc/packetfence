import { ref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
import store from '@/store' // required for 'system/version'
import apiCall from '@/utils/api'

export const IDENTIFIER_PREFIX = 'pfappserver::' // transparently prefix all identifiers - avoid key collisions

const api = {
  allPreferences: () => {
    return apiCall.getQuiet('preferences').then(response => {
      return response.data.items
    })
  },
  getPreference: id => {
    return apiCall.getQuiet(`preference/${IDENTIFIER_PREFIX}${id}`).then(response => {
      return response.data.item
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

export const usePreference = (id, defaultValue) => {

  const preference = ref(defaultValue)
  let debouncer

  api.getPreference(id)
    .then(response => {
      const { value } = response || {}
      const { data } = JSON.parse(value || '{}')
      preference.value = data
    })
    .catch(() => {
      preference.value = defaultValue
    })

  watch(preference, () => {
    if (!debouncer)
      debouncer = createDebouncer()
    debouncer({
      handler: () => {
        if (!preference.value)
          api.removePreference(id)
        else
          api.setPreference(id, preference.value)
      },
      time: 1000
    })
  }, { deep: true })

  return preference
}