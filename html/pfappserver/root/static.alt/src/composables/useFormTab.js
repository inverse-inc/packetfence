import { computed, ref } from '@vue/composition-api'
import { useQuerySelectorAll } from './useDom'

export const useFormTabProps = {}

export const useFormTab = () => {
  // template refs
  const rootRef = ref(null)

  const _invalidNodes = useQuerySelectorAll(rootRef, '.form-group.is-invalid')
  const isValid = computed(() => (!_invalidNodes.value || _invalidNodes.value.length === 0))
  const numInvalid = computed(() => (isValid.value) ? 0 : _invalidNodes.value.length)

  return {
    rootRef,
    isValid,
    numInvalid
  }
}
