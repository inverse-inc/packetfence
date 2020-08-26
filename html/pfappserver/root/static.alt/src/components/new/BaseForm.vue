<template>
  <div>
    <slot/>
  </div>
</template>
<script>
import { useFormProvide, useFormProvideProps } from '@/composables/useFormProvide'

export const props = {
  ...useFormProvideProps,
}

export const setup = (props, context) => {
  return useFormProvide(props, context)
}

// @vue/component
export default {
  name: 'base-form',
  inheritAttrs: false,
  props,
  setup
}
</script>
