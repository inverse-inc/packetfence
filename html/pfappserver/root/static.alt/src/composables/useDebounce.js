import { ref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'

export const useDebouncedWatchHandler = (watching, _handler, time = 300) => {
  const value = ref(undefined)
  let debouncer
  watch(watching, (...args) => {
    if (!debouncer)
      debouncer = createDebouncer()
    debouncer({
      handler: () => {
        value.value = _handler(args)
      },
      time
    })
  }, { deep: true, immediate: true })
  return value
}
