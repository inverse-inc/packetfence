/**
 * A directive to set all parent nodes to the height of the window.
 * The current element is set to be scrollable (automatic overflow).
 */

import Vue from 'vue'

export default Vue.directive('scroll-100', {
  update: function (el) {
    el.classList.add('h-100', 'overflow-auto')
    // Force all parent nodes to take 100% of the window height
    let parentNode = el.parentNode
    while (parentNode && 'classList' in parentNode) {
      parentNode.classList.add('h-100')
      parentNode = parentNode.parentNode
    }
  },
  unbind: function (el) {
    el.classList.remove('h-100', 'overflow-auto')
    // Remove height constraint on all parent nodes
    let parentNode = el.parentNode
    while (parentNode && 'classList' in parentNode) {
      parentNode.classList.remove('h-100')
      parentNode = parentNode.parentNode
    }
  }
})