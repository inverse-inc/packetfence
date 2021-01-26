import { ref } from '@vue/composition-api'
import useEvent from './useEvent'

export default function useEventEscapeKey(el = ref(document)) {
  let escapeKey = ref(false)

  useEvent('keydown', e => {
    const { target, keyCode } = e
    escapeKey.value = (
      keyCode === 27 &&
      el.value &&
      (
        !target
        || document.body.isSameNode(target)
        || el.value.contains(target)
      )
    )
  })

  useEvent('keyup', () => {
    if (!escapeKey.value)
      return
    escapeKey.value = false
  })

  return escapeKey
}
