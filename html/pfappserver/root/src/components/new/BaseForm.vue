<template>
  <div class="base-form">
    <slot/>
  </div>
</template>
<script>
import { useFormProvide, useFormProvideProps } from '@/composables/useFormProvide'

export const props = useFormProvideProps

export const setup = (props, context) => useFormProvide(props, context)

// @vue/component
export default {
  name: 'base-form',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.base-form {
  padding-top: 1rem;
  padding-right: 0;
  padding-bottom: 0;
  padding-left: 0;

  & > .form-group {
    margin-right: 1rem !important;
    margin-left: 1rem !important;
  }
  & > .tabs > .tab-content > .tab-pane {
    padding-top: 1rem !important;
    padding-right: 1rem !important;
    padding-left: 1rem !important;
  }
}
</style>
