<template>
  <div class="base-flex-wrap" align-v="center">

    <base-input-chosen-one ref="typeComponentRef"
      :namespace="`${namespace}.type`"
      :options="typeOptions"
    />

    <component :is="valueComponent" ref="valueComponentRef"
      :namespace="`${namespace}.value`"
      :placeholder="valuePlaceholder"
    />

  </div>
</template>
<script>
import {
  BaseInputNumber,
  BaseInputChosenOne
} from '@/components/new'

const components = {
  BaseInputNumber,
  BaseInputChosenOne
}

import { deviceAttributes } from '../config'
import { computed, nextTick, ref, unref, watch } from '@vue/composition-api'
import {
  pfComponentType as componentType,
  pfFieldTypeComponent as fieldTypeComponent
} from '@/globals/pfField'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    value: inputValue,
    onChange
  } = useInputValue(metaProps, context)

  const typeComponentRef = ref(null)
  const typeOptions = Object.values(deviceAttributes)

  watch( // when `type` is mutated
    () => unref(inputValue) && unref(inputValue).type,
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

  const valueComponentRef = ref(null)
  const valueComponent = computed(() => {
    const { type } = unref(inputValue) || {}
    const { [type]: { types = [] } = {} } = deviceAttributes
    for (let t = 0; t < types.length; t++) {
      let type = types[t]
      let component = fieldTypeComponent[type]
      switch (component) {
        case componentType.INTEGER:
          return BaseInputNumber
          // break

        case componentType.HIDDEN:
        case componentType.NONE:
          return undefined
          // break

        default:
          // eslint-disable-next-line
          console.error(`Unhandled pfComponentType '${component}' for pfFieldType '${type}'`)
      }
    }
  })

  const valuePlaceholder = computed(() => {
    const { type } = unref(inputValue) || {}
    const { [type]: { defaultWeight } = {} } = deviceAttributes
    return defaultWeight
  })

  return {
    typeComponentRef,
    typeOptions,
    valueComponent,
    valueComponentRef,
    valuePlaceholder
  }
}

// @vue/component
export default {
  name: 'base-form-group-device-attributes-diff-threshold-overrides',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

