import { computed, inject, ref, unref, watch } from '@vue/composition-api'

export const useFormQuerySelector = (el, selector = ref(''), triggers) => {

  const $el = computed(() => ('$el' in unref(el)) ? unref(el).$el : el)

  const lastTick = inject('lastTick', ref(null))
  const result = ref(null)

  watch(triggers || lastTick, () => {
    result.value = unref($el).querySelector(unref(selector))
  }, { deep: true })

  return result
}

export const useFormQuerySelectorAll = (el, selector = ref(''), triggers) => {

  const $el = computed(() => ('$el' in unref(el)) ? unref(el).$el : el)

  const lastTick = inject('lastTick', ref(null))
  const result = ref([])

  watch(triggers || lastTick, () => {
    result.value = unref($el).querySelectorAll(unref(selector))
  }, { deep: true })

  return result
}
