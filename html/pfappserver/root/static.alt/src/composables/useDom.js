import { computed, onMounted, onBeforeUnmount, ref } from '@vue/composition-api'

export const useMutationObserver = (el, callback, config = {}) => {
  const observer = new MutationObserver(callback)
  const removeObserver = () => observer.disconnect()

  onMounted(() => {
    const _el = (el.constructor === Function) ? el() : el
    return Promise.resolve(_el).then(el => observer.observe(el, { attributes: false, childList: true, subtree: true, ...config }))
  })
  onBeforeUnmount(removeObserver)

  return removeObserver
}

export const useResizeObserver = (el, callback, config = {}) => {
  const observer = new ResizeObserver(callback)
  const removeObserver = () => observer.disconnect()

  onMounted(() => {
    const _el = (el.constructor === Function) ? el() : el
    return Promise.resolve(_el).then(el => observer.observe((el.value || el), { box: 'border-box', ...config }))
  })
  onBeforeUnmount(removeObserver)

  return removeObserver
}

export const useQuerySelector = (el, selector) => {
  const result = ref(null)
  useMutationObserver(
    () => {
      const { value: { $el } = {} } = el
      return $el || el
    },
    () => {
      const { value: { $el } = {} } = el
      result.value = ($el || el).querySelector(selector)
    }
  )
  return result
}

export const useQuerySelectorAll = (el, selector) => {
  const result = ref(null)
  useMutationObserver(
    () => {
      const { value: { $el } = {} } = el
      return $el || el
    },
    () => {
      const { value: { $el } = {} } = el
      result.value = ($el || el).querySelectorAll(selector)
    }
  )
  return result
}
