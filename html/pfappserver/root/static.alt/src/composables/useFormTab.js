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
  const numInvalid = ref(0)

  let isValidDebouncer
  watch([form, meta], () => {
    isValid.value = true // temporary
    if (!isValidDebouncer)
      isValidDebouncer = createDebouncer()
    isValidDebouncer({
      handler: () => {
        const length = rootRef.value.$el.querySelectorAll('.form-group.is-invalid').length
        isValid.value = rootRef.value && length === 0
        numInvalid.value = (isValid.value) ? 0 : length
      },
      time: 300
    })
  }, { deep: true })

  return {
    rootRef,
    isValid,
    numInvalid
  }
}
