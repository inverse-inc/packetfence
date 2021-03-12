import { onMounted, onBeforeUnmount, ref } from '@vue/composition-api'

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
      const { value, value: { $el } = {} } = el || {}
      return $el || value || el
    },
    () => {
      const { value, value: { $el } = {} } = el || {}
      result.value = ($el || value || el).querySelector(selector)
    }
  )
  return result
}

export const useQuerySelectorAll = (el, selector) => {
  const result = ref(null)
  useMutationObserver(
    () => {
      const { value, value: { $el } = {} } = el || {}
      return $el || value || el
    },
    () => {
      const { value, value: { $el } = {} } = el || {}
      result.value = ($el || value || el).querySelectorAll(selector)
    }
  )
  return result
}
