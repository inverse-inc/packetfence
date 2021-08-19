<template>
  <b-progress class="fixed-top" height="4px" max="100" :value="percentage" v-show="visible"></b-progress>
</template>

<script>
import { computed, ref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const percentage = computed(() => $store.getters['performance/getPercentage'])
  const isLoading = computed(() => $store.getters['performance/isLoading'])
  watch(isLoading, a => {
    if (a)
      this.show()
    else
      this.hide()
  }, { immediate: true })

  let $debouncer
  const visible = ref(false)
  const show = () => {
    visible.value = true
  }
  const hide = () => {
    if (!$debouncer)
      $debouncer = createDebouncer()
    $debouncer({
      handler: () => {
        if (!isLoading.value)
          visible.value = false
      },
      time: 1000 // 1 second
    })
  }

  return {
    percentage,
    isLoading,
    visible,
    show,
    hide
  }
}

// @vue/component
export default {
  name: 'app-api-progress',
  setup
}
</script>

<style lang="scss" scoped>
  .fixed-top {
    background-color: $gray-700;
  }
  .progress {
    z-index: $zindex-modal;
    overflow: visible !important;
  }
  .progress /deep/ .progress-bar {
    box-shadow: 0 0 10px rgba($primary,.7);
  }
</style>
