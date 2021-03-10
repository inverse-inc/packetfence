import { ref } from '@vue/composition-api'
import useEvent from './useEvent'

export default function useEventActionKey(el = ref(document)) {

  let actionKey = ref(false)

  useEvent('keydown', e => {
    const { ctrlKey = false, metaKey = false, target } = e
    actionKey.value = (
      (ctrlKey || metaKey) &&
      (
        !target
        || document.body.isSameNode(target)
        || el.value.contains(target)
      )
    )
  })

  useEvent('keyup', () => {
    if (!actionKey.value)
      return
    actionKey.value = false
  })

  useEvent('blur', () => {
    if (!actionKey.value)
      return
    actionKey.value = false
  }, ref(window))

  return actionKey
}
