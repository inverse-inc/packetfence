import { computed, ref, unref } from '@vue/composition-api'
import { useFormQuerySelectorAll } from './useFormQuerySelector'

export const useFormTabProps = {}

export const useFormTab = () => {
  // template refs
  const rootRef = ref(null)

  const invalidElements = useFormQuerySelectorAll(rootRef, '.form-group.is-invalid')
  const isValid = computed(() => unref(rootRef) && unref(invalidElements).length === 0)
  const numInvalid = computed(() => (unref(isValid)) ? 0 : unref(invalidElements).length)

  return {
    rootRef,
    isValid,
    numInvalid
  }
}
