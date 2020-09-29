<template>
  <draggable v-model="inputValue"
        class="w-100"
        handle=".draggable-handle"
        dragClass="draggable-copy"

        @start="onDragStart"
        @end="onDragEnd"
  >

    <slot/>

  </draggable>
</template>
<script>
import draggable from 'vuedraggable'

export const components = {
  draggable
}

import { useInputMeta, useInputMetaProps } from '@/composables/useInputMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

export const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    value,
    onInput,
    onChange
  } = useInputValue(metaProps, context)

  const onDragStart = (...args) => {
    console.log('onDragStart', {args})
  }
  const onDragEnd = (...args) => {
    console.log('onDragEnd', {args})
  }

  return {
    // useInputValue
    inputValue: value,
    onInput,
    onChange,

onDragStart,
onDragEnd
  }
}

// @vue/component
export default {
  name: 'base-draggable',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
