<template>
  <div class="base-accept-vlan base-flex-wrap" align-v="center">

    <base-input-chosen-one-searchable ref="typeComponentRef"
      :namespace="`${namespace}.type`"
    />

    <component :is="valueComponent" ref="valueComponentRef"
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
  BaseInputChosenOneSearchable
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

  const typeComponentRef = ref(null)
  const valueComponentRef = ref(null)

  const type = computed(() => {
    const { type } = inputValue.value || {}
    return type
  })

  const radiusAttributeType = computed(() => {
    if (type.value in radiusAttributes.value)
      return radiusAttributes.value[type.value]
    return {}
  })

  watch(type, () => { // when `type` is mutated
    const { isFocus = false } = typeComponentRef.value
    if (isFocus) { // and `type` isFocus
      onChange({ ...unref(inputValue), value: undefined }) // clear `value`

      nextTick(() => {
        const { doFocus = () => {} } = valueComponentRef.value || {}
        doFocus() // focus `value` component
      })
    }
  })

  const valueComponent = computed(() => {
    if (valueOptions.value)
      return BaseInputChosenOne
    return BaseInput
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
    typeComponentRef,

    valueComponent,
    valueComponentRef,
    valueOptions,
    valuePlaceholder
  }
}

// @vue/component
export default {
  name: 'base-accept-vlan',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
.base-accept-vlan {
  .btn {
    margin: 0.25rem !important;
  }
}
</style>
