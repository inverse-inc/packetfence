import { computed, ref, unref } from '@vue/composition-api'
import { useQuerySelectorAll } from './useDom'

export const useFormTabProps = {}

export const useFormTab = () => {
  // template refs
  const rootRef = ref(null)

  const isInvalidElements = useQuerySelectorAll(rootRef, '.form-group.is-invalid')
  const isValid = computed(() => unref(rootRef) && unref(isInvalidElements).length === 0)
  const numInvalid = computed(() => (unref(isValid)) ? 0 : unref(isInvalidElements).length)

  return {
    rootRef,
    isValid,
    numInvalid
  }
}
