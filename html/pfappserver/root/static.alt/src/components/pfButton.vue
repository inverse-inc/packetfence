<template>
  <b-button
    v-bind="$attrs"
    :type="type"
    :variant="variant"
  >
    <icon name="circle-notch" spin v-if="isLoading"></icon>
    <template v-else-if="label">
      {{ label }}
    </template>
    <template v-else>
      <slot>Button</slot>
    </template>
  </b-button>
</template>

<script>
export default {
  name: 'pf-button',
  props: {
    label: {
      type: String,
      default: null
    },
    type: {
      type: String,
      default: 'button'
    },
    variant: {
      type: String,
      default: 'primary'
    },
    isLoading: {
      type: Boolean,
      default: false
    }
  }
}
</script>
