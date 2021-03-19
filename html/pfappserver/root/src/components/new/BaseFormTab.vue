<template>
  <b-tab ref="rootRef"
    :active="active"
    :title-link-class="{ 'has-invalid': !isValid }"
  >
    <template #title>
      <slot name="title">
        {{ title }} <b-badge pill variant="danger" class="num-invalid ml-1" :data-num-invalid="numInvalid">{{ numInvalid }}</b-badge>
      </slot>
    </template>
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
  const {
    rootRef,
    isValid,
    numInvalid
  } = useFormTab(props, context)

  return {
    rootRef,
    isValid,
    numInvalid
  }
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
    position: relative;
    &.has-invalid {
      color: $form-feedback-invalid-color;
    }
    &.active.has-invalid {
      border-color: $form-feedback-invalid-color;
    }
    > .num-invalid {
      position: absolute;
      top: 0;
      right: 0;
      transform: translate(+25%, -25%);
      &[data-num-invalid="0"] {
        display: none;
      }
    }
  }
}
</style>
