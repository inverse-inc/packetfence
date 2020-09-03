import { inject, ref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'

export const useFormTabProps = {}

export const useFormTab = () => {
  // template refs
  const rootRef = ref(null)

  const form = inject('form', ref({}))
  const meta = inject('meta', ref({}))

  // state
  const isValid = ref(true)
  let isValidDebouncer
  watch([form, meta], () => {
    isValid.value = false // temporary
    if (!isValidDebouncer)
      isValidDebouncer = createDebouncer()
    isValidDebouncer({
      handler: () => isValid.value = rootRef.value && rootRef.value.$el.querySelectorAll('.is-invalid').length === 0,
      time: 300
    })
  }, { deep: true })

  return {
    rootRef,
    isValid
  }
}
