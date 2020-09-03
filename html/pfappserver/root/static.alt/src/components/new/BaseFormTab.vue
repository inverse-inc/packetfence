<template>
  <b-tab ref="rootRef"
    :active="active"
    :title="title"
    :title-link-class="{ 'has-invalid': !isValid }"
  >
    <slot/>
  </b-tab>
</template>
<script>
import { useFormTab, useFormTabProps } from '@/composables/useFormTab'

export const props = {
  active: {
    type: Boolean
  },
  title: {
    type: String
  },
  ...useFormTabProps
}

export const setup = (props, context) => {
  return useFormTab(props, context)
}

// @vue/component
export default {
  name: 'base-form-tab',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.nav-tabs {
  .nav-link {
    transition: 300ms ease all;

    &.has-invalid {
      color: $form-feedback-invalid-color;
    }
    &.active.has-invalid {
      border-color: $form-feedback-invalid-color;
    }
  }
}
</style>
