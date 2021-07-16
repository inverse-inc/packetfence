/**
 * A directive to set all parent nodes to the height of the window.
 * The current element is set to be scrollable (automatic overflow).
 */

export default {
  inserted(el) {
    el.classList.add('h-100', 'overflow-auto')
    // Force all parent nodes to take 100% of the window height
    let parentNode = el.parentNode
    while (parentNode && 'classList' in parentNode) {
      parentNode.classList.add('scroll-100', 'h-100')
      parentNode = parentNode.parentNode
    }
  },
  unbind(el) {
    el.classList.remove('h-100', 'overflow-auto')
    // Remove height constraint on all parent nodes
    let parentNode = el.parentNode
    while (parentNode && 'classList' in parentNode) {
      parentNode.classList.remove('scroll-100', 'h-100')
      parentNode = parentNode.parentNode
    }
    // Element is detached, remove height constraint on all remaining nodes of document
    let parentNodes = Array.from(document.getElementsByClassName('scroll-100 h-100'))
    parentNodes.forEach(parentNode => {
      parentNode.classList.remove('scroll-100', 'h-100')
    })
  }
}