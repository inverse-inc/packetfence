<template>
  <div class="base-flex-wrap" align-v="center">

    <base-input-chosen-one ref="prefixComponentRef"
      :namespace="`${namespace}.prefix`"
    />

    <base-input-chosen-one-searchable ref="typeComponentRef" v-if="prefixValue"
      :namespace="`${namespace}.type`"
    />

    <component :is="valueComponent" ref="valueComponentRef" v-if="typeValue"
      :namespace="`${namespace}.value`"
      :options="valueOptions"
      :placeholder="valuePlaceholder"
    />

  </div>
</template>
<script>
import {
  BaseInput,
  BaseInputChosenOne,
  BaseInputChosenOneSearchable,
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputChosenOne,
  BaseInputChosenOneSearchable
}

import { computed, inject, nextTick, ref, unref, watch } from '@vue/composition-api'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = (props, context) => {

  // inject radiusAttributes from ancestor
  const radiusAttributes = inject('radiusAttributes', ref({}))

  const metaProps = useInputMeta(props, context)

  const {
    value: inputValue,
    onChange
  } = useInputValue(metaProps, context)

  const prefixComponentRef = ref(null)
  const typeComponentRef = ref(null)
  const valueComponentRef = ref(null)

  const prefix = computed(() => {
    const { prefix } = inputValue.value || {}
    return prefix
  })

  watch(prefix, // when `prefix` is mutated
    () => {
      const { isFocus = false } = prefixComponentRef.value
      if (isFocus) { // and `prefix` isFocus
        onChange({ ...unref(inputValue), type: undefined, value: undefined }) // clear `type` and `value`

        nextTick(() => {
          const { doFocus = () => {} } = typeComponentRef.value || {}
          doFocus() // focus `type` component
        })
      }
    }
  )

  const type = computed(() => {
    const { type } = inputValue.value || {}
    return type
  })

  watch(type, // when `type` is mutated
    () => {
      const { isFocus = false } = typeComponentRef.value
      if (isFocus) { // and `type` isFocus
        onChange({ ...unref(inputValue), value: undefined }) // clear `value`

        nextTick(() => {
          const { doFocus = () => {} } = valueComponentRef.value || {}
          doFocus() // focus `value` component
        })
      }
    }
  )

  const valueComponent = computed(() => {
    if (valueOptions.value)
      return BaseInputChosenOne
    else if (type.value)
      return BaseInput
    else
      return // undefined
  })

  const radiusAttributeType = computed(() => {
    if (type.value in radiusAttributes.value)
      return radiusAttributes.value[type.value]
    return {}
  })

  const valueOptions = computed(() => {
    const { allowed_values } = radiusAttributeType.value
    if (allowed_values)
      return allowed_values.map(({ name, value }) => ({ text: name, value: `${value}` }))
  })

  const valuePlaceholder = computed(() => {
    const { placeholder } = radiusAttributeType.value
    return placeholder
  })

  return {
    prefixComponentRef,
    prefixValue: prefix,

    typeComponentRef,
    typeValue: type,

    valueComponentRef,
    valueComponent,
    valueOptions,
    valuePlaceholder
  }
}

// @vue/component
export default {
  name: 'base-answer',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
