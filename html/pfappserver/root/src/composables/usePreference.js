
import store from '@/store'
import { ref, watch } from '@vue/composition-api'

export default (id, key, defaultValue) => {
  const preference = ref(defaultValue)
  let isLoaded = false
  let isInterrupted = false
  watch(preference, () => {
    if (isLoaded) {
      const { meta, ...currentValue } = store.state.preferences.cache[id]
      store.dispatch('preferences/setDebounced', { id, value: { ...currentValue, [key]: preference.value } })
    }
    else {
      isInterrupted = true
    }
  }, { deep: true })
  store.dispatch('preferences/get', id).then(value => {
    isLoaded = true
    if (!isInterrupted) {
      preference.value = value[key] || defaultValue
    }
    isInterrupted = false
  })
  return preference
}