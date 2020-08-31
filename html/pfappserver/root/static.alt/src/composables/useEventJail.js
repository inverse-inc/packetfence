import { ref } from '@vue/composition-api'
import useEvent from './useEvent'

export default function useEventJail(el = ref(document)) {

  let isStyled = false
  let isJailed = false

  useEvent('mouseover', e => {
    const { target } = e
    if (el.value && !el.value.contains(target)) {
      isJailed = false
      el.value.blur()
    }
  })

  useEvent('focus', () => {
    isJailed = true
  }, el)

  useEvent('mouseover', e => {
    if (!isStyled) {
      el.value.tabIndex = 0
      el.value.setAttribute('style', 'outline: none;')
      isStyled = true
    }
    if (isJailed)
      return
    const { target } = e
    if (el.value.contains(target)) {
       el.value.focus()
    }
  }, el)

  useEvent('mouseout', e => {
    if (!isJailed)
      return
    const { target } = e
    if (el.value.isSameNode(target) || !el.value.contains(target)) {
      isJailed = false
    }
  }, el)

  return isJailed
}
