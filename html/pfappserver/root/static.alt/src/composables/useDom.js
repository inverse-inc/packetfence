import { computed, inject, nextTick, onMounted, onBeforeUnmount, ref, watch } from '@vue/composition-api'

export const useMutationObserver = (el, callback, config = { attributes: false, childList: true, subtree: true }) => {
  const observer = new MutationObserver(callback)
  const removeObserver = () => observer.disconnect()

  onMounted(() => el.value && observer.observe(el.value, config))
  onBeforeUnmount(removeObserver)

  return removeObserver
}

export const useQuerySelector = (el, selector, triggers) => {
  const $el = computed(() => ('$el' in el.value) ? el.value.$el : el)
  const result = ref(null)

  useMutationObserver($el, () => {
    result.value = $el.value.querySelector(selector)
  })

  return result
}

export const useQuerySelectorAll = (el, selector) => {
  const $el = computed(() => ('$el' in el.value) ? el.value.$el : el)
  const result = ref([])

  useMutationObserver($el, () => {
    result.value = $el.value.querySelectorAll(selector)
  })

  return result
}
