import { nextTick } from '@vue/composition-api'

const attributeName = 'data-focus-after'

export default {
  inserted(el) {
    el.focus()
  },
  // focus is lost or blackholed when element is disabled after focus
  // use element attribute to track disabled/enabled
  update(el, binding, vm) {
    if (vm.child.disabled || vm.child.readonly) { // disabled
      el.setAttribute(attributeName, true)
    }
    else if (el.getAttribute(attributeName)) { // enabled
      el.removeAttribute(attributeName)
      nextTick(() => {
        el.focus()
      })
    }
  }
}
