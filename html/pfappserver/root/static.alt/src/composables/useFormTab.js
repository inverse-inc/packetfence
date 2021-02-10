import { computed, ref } from '@vue/composition-api'
import { useQuerySelectorAll } from './useDom'

export const useFormTabProps = {}

export const useFormTab = () => {
  // template refs
  const rootRef = ref(null)

  const _invalidNodes = useQuerySelectorAll(rootRef, '.form-group.is-invalid')
  const _visibleInvalidNodes = computed(() => Array.prototype.slice.call(_invalidNodes.value)
    .filter(el => el.closest('fieldset').style.display !== 'none') // handle v-show <.. style="display: none;">
  )
  const isValid = computed(() => (!_invalidNodes.value || _visibleInvalidNodes.value.length === 0))
  const numInvalid = computed(() => (isValid.value) ? 0 : _visibleInvalidNodes.value.length)

  return {
    rootRef,
    isValid,
    numInvalid,

    _invalidNodes,
    _visibleInvalidNodes
  }
}
