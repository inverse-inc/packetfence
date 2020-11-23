<template>
  <pre>{{ {inputValue, operators} }}</pre>
</template>
<script>
import { computed, toRefs, ref } from '@vue/composition-api'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import BaseConditionValue from './BaseConditionValue'

const components = {
  BaseConditionValue
}

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)
  const {
    options
  } = toRefs(metaProps)

  const {
    value,
    onChange,
    onInput
  } = useInputValue(metaProps, context)

  const operators = computed(() => {
console.log({options})
    if (options && options.value) {
      return options.value
        .filter(option => {
  console.log({option})
          const { requires = [] } = option
          return requires.includes('values') || requires.length === 0
        })
        .map(option => {
          const { value } = option
          return value
        })
    }
  })

  return {
    // useInputValue
    inputValue: value,
    onChange,
    onInput,

    operators
  }
}

// @vue/component
export default {
  name: 'base-condition-value',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
