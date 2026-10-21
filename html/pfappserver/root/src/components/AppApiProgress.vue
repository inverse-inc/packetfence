<template>
  <b-progress class="fixed-top" height="6px" max="100" :value="percentage" v-show="visible"></b-progress>
</template>

<script>
import { computed, ref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

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

  const percentage = computed(() => $store.getters['performance/getPercentage'])
  const isLoading = computed(() => $store.getters['performance/isLoading'])
  watch(isLoading, a => {
    if (a)
      show()
    else
      hide()
  }, { immediate: true })

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
    box-shadow: 0 2px 8px 2px rgba($black, 0.5), 0 4px 20px 4px rgba($black, 0.3);
    animation: pulse-glow 1.5s ease-in-out infinite;
    transition: width 0.15s linear;
  }
  @keyframes pulse-glow {
    0%, 100% { box-shadow: 0 2px 8px 2px rgba($black, 0.5), 0 4px 20px 4px rgba($black, 0.3); }
    50% { box-shadow: 0 2px 12px 3px rgba($black, 0.7), 0 4px 28px 6px rgba($black, 0.4); }
  }
</style>
