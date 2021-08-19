<template>
    <div>
        <div class="icon-counter" :class="variant" v-if="notEmpty">
          <slot>{{ count }}</slot>
        </div>
        <icon :name="name" v-bind="$attrs"></icon>
    </div>
</template>

<script>
const props = {
  name: {
    type: String
  },
  variant: {
    type: String,
    default: 'danger'
  },
  value: {
    type: Number,
    default: 0
  }
}

import { computed, toRefs } from '@vue/composition-api'

const setup = props => {

  const {
    value
  } = toRefs(props)

  const count = computed(() => (value.value > 99) ? '!!' : value.value)
  const notEmpty = computed(() => value.value > 0)

  return {
    count,
    notEmpty
  }
}

// @vue/component
export default {
  name: 'icon-counter',
  inheritAttrs: false,
  props,
  setup
}
</script>

<style lang="scss">
/* See styles/_icon-counter.scss */
</style>
