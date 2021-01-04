import { computed, onMounted, onBeforeUnmount, ref } from '@vue/composition-api'

export const useMutationObserver = (el, callback, config = { attributes: false, childList: true, subtree: true }) => {
  const observer = new MutationObserver(callback)
  const removeObserver = () => observer.disconnect()

  onMounted(() => el && observer.observe((el.value || el), config))
  onBeforeUnmount(removeObserver)

  return removeObserver
}

export const useResizeObserver = (el, callback, config = { box: 'border-box' }) => {
  const observer = new ResizeObserver(callback)
  const removeObserver = () => observer.disconnect()
console.log('el', (el.value || el))
  onMounted(() => el && observer.observe((el.value || el), config))
  onBeforeUnmount(removeObserver)

  return removeObserver
}

export const useQuerySelector = (el, selector) => {
  const $el = computed(() => (el && el.value && '$el' in el.value) ? el.value.$el : el)
  const result = ref(null)

  useMutationObserver($el, () => {
    result.value = $el.value.querySelector(selector)
  })

  return result
}

export const useQuerySelectorAll = (el, selector) => {
  const $el = computed(() => (el && el.value && '$el' in el.value) ? el.value.$el : el)
  const result = ref([])

  useMutationObserver($el, () => {
    result.value = $el.value.querySelectorAll(selector)
  })

  return result
}
