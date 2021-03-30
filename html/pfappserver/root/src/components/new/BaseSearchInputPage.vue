<template>
  <b-pagination class="mr-3" align="right" 
    :per-page="limit" 
    :total-rows="totalRows" 
    :value="value"
    :disabled="disabled"
    @change="onInput" 
  />
</template>
<script>
const props = {
  value: {
    type: [Number, String]
  },
  limit: {
    type: [Number, String]
  },
  totalRows: {
    type: [Number, String]
  },
  disabled: {
    type: Boolean
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
  name: 'base-search-input-page',
  inheritAttrs: false,
  props,
  setup
}
</script>
