import { ref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'

export const useDebouncedWatchHandler = (watching, _handler, options) => {
  let {
    debouncer,
    deep = true,
    immediate = true,
    time = 300
  } = options || {}
  const value = ref(undefined)
  watch(watching, (...args) => {
    if (!debouncer)
      debouncer = createDebouncer()
    debouncer({
      handler: () => {
        value.value = _handler(args)
      },
      time
    })
  }, { deep, immediate })
  return value
}
