import { computed, ref } from '@vue/composition-api'
import { useQuerySelectorAll } from './useDom'

export const useFormTabProps = {}

export const useFormTab = () => {
  // template refs
  const rootRef = ref(null)

  const _isValidNodes = useQuerySelectorAll(rootRef, '.form-group.is-invalid')
  const isValid = computed(() => (!_isValidNodes.value || Array.prototype.slice.call(_isValidNodes.value).length === 0))
  const numInvalid = computed(() => (isValid.value) ? 0 : _isValidNodes.value.length)

  return {
    rootRef,
    isValid,
    numInvalid
  }
}
