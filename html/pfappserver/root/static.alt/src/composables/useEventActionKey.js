import { ref } from '@vue/composition-api'
import useEvent from './useEvent'

export default function useEventActionKey(el = ref(document)) {
  let actionKey = ref(false)

  useEvent('mouseover', e => {
    const { ctrlKey = false, metaKey = false } = e
    if (ctrlKey || metaKey)
      actionKey.value = true
    // tabIndex inc target w/ key(down|up) event bindings
    el.value.tabIndex = 0
    el.value.setAttribute('style', 'outline: none;')
    el.value.focus()
  }, el)

  useEvent('mouseout', e => {
    if (!actionKey.value)
      return
    // suppress child DOM nodes
    const { toElement } = e
    if (el.value.isSameNode(toElement) || !(el.value && el.value.contains(toElement))) {
      actionKey.value = false
      el.value.blur()
    }
  }, el)

  useEvent('keydown', e => {
    const { ctrlKey = false, metaKey = false, target } = e
    if (el.value.contains(target))
      actionKey.value = (ctrlKey || metaKey)
  })

  useEvent('keyup', e => {
    if (!actionKey.value)
      return
    actionKey.value = false
  })

  return actionKey
}
