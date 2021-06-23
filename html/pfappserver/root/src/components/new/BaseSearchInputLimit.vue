<template>
  <b-form inline>
    <b-form-select :size="size"
      :options="limits"
      :disabled="disabled"
      :value="value" @input="onInput"
    />
  </b-form>
</template>
<script>
const props = {
  value: {
    type: [Number, String]
  },
  disabled: {
    type: Boolean
  },
  limits: {
    type: Array
  },
  size: {
    type: String,
    default: 'sm'
  }
}

const setup = (props, context) => {

  const { emit } = context

  const onInput = value => emit('input', value)

  return {
    onInput
  }

}

// @vue/component
export default {
  name: 'base-search-input-limit',
  inheritAttrs: false,
  setup,
  props
}
</script>
