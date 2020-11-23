<template>
  <div>
    <pre>{{ {inputValue, namespace, operators} }}</pre>

    <base-input-chosen-one :namespace="`${namespace}.op`"
      :options="operatorOptions"
    />

  </div>
</template>
<script>
import { computed, toRefs } from '@vue/composition-api'
import { useInputMeta, useInputMetaProps, useNamespaceMetaAllowed } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import {
  BaseInputChosenOne
} from '@/components/new/'
import BaseConditionValue from './BaseConditionValue'
import { pfOperators } from '@/globals/pfOperators'

const components = {
  BaseConditionValue,
  BaseInputChosenOne
}

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = (props, context) => {

  const {
    namespace
  } = toRefs(props)

  const metaProps = useInputMeta(props, context)

  const {
    value,
    onChange,
    onInput
  } = useInputValue(metaProps, context)

  const operatorOptions = computed(() => useNamespaceMetaAllowed(`${namespace.value}.op`)
    .filter(({ requires = [] }) => requires.includes('values') || requires.length === 0)
    .map(({ value }) => {
        const { [value]: text = value } = pfOperators
        return { text, value }
    })
  )

  return {
    // useInputValue
    inputValue: value,
    onChange,
    onInput,

    operatorOptions,
  }
}

// @vue/component
export default {
  name: 'base-condition',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
