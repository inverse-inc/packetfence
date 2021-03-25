<template>
  <b-form inline class="mb-0">
    <b-form-select class="mb-3 mr-3" size="sm" 
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
