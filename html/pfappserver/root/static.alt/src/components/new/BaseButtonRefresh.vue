<template>
  <button type="button" :aria-label="$t('Refresh')" :disabled="isLoading || disabled"
    class="base-button-refresh mx-3"
    v-b-tooltip.hover.left.d300 :title="$t('Refresh [Alt + R]')"
    @click="onClick"
  >
    <icon v-if="interval" name="history" :style="`transform: rotate(${rotate}deg) scaleX(-1)`" :class="{ 'text-primary': actionKey }"></icon>
    <icon v-else name="redo" :style="`transform: rotate(${rotate}deg)`" :class="{ 'text-primary': actionKey }"></icon>
  </button>
</template>

<script>
import { createDebouncer } from 'promised-debounce'

const props = {
  isLoading: {
    type: Boolean
  }
}

import { computed, ref } from '@vue/composition-api'

const setup = (props, context) => {
  
  const { emit } = context

  const num = ref(0)
  const disabled = ref(false)
  let debouncer
  let interval
  const timeout = 15000
  
  const rotate = computed(() => num.value * 360)
  
  const onClick = event => {
    const { ctrlKey, metaKey } = event
    if (ctrlKey || metaKey) {
      if (interval) { // clear interval
        clearInterval(interval)
        interval = false
      } else { // create interval
        interval = setInterval(onInterval, timeout)
        this.refresh(event)
      }
    } else {
      if (interval) { // reset interval
        clearInterval(interval)
        interval = setInterval(onInterval, timeout)
      }
      onInterval(event)
    }
    
  }
  
  const onInterval = event => {
    disabled.value = true
    if (!debouncer) {
      debouncer = createDebouncer()
    }
    debouncer({
      handler: () => {
        num.value++
        emit('refresh', event)
        disabled.value = false
      },
      time: 300 // 300 milli-seconds
    })    
  }
  
  return {
    disabled,
    rotate,
    onClick
  }
}

// @vue/component
export default {
  name: 'base-button-refresh',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
button {
  &.base-button-refresh {
    padding: 0;
    background-color: transparent;
    border: 0;
    outline: 0;
  }
  svg {
    transition: 300ms ease all;
  }
}
.base-button-refresh {
  float: right;
  font-size: 1.35rem;
  font-weight: 700;
  line-height: 1;
  color: #000;
  text-shadow: 0 1px 0 #fff;
  opacity: .5;
}
</style>
