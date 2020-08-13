<template>
  <fragment>
    <slot/>
  </fragment>
</template>
<script>
import { useFormProvide, useFormProvideProps } from '@/composables/useFormProvide'

export const props = {
  ...useFormProvideProps,
}

// @vue/component
export default {
  name: 'base-form',
  inheritAttrs: false,
  props,
  setup(props, context) {

    useFormProvide(props, context)

    return {
      /* noop */
    }
  }
}
</script>
