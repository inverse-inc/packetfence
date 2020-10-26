<template>
  <b-row class="w-100 mx-0 mb-1 px-0" align-v="center" no-gutters>
    <b-col sm="6" align-self="start">

      <base-input-chosen-one ref="typeComponentRef"
        :namespace="`${namespace}.type`"
        :options="typeOptions"
      />

    </b-col>
    <b-col sm="6" align-self="start" class="pl-1">

      <component :is="valueComponent" ref="valueComponentRef"
        :namespace="`${namespace}.value`"
      />

    </b-col>
  </b-row>
</template>
<script>
import {
  BaseInput,
  BaseInputNumber,
  BaseInputChosenOne
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputNumber,
  BaseInputChosenOne
}

import { inlineTriggers } from '../config'
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
  const typeOptions = Object.values(inlineTriggers)

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
    const { [type]: { types = [] } = {} } = inlineTriggers
    for (let t = 0; t < types.length; t++) {
      let type = types[t]
      let component = fieldTypeComponent[type]
      switch (component) {
        case componentType.SUBSTRING:
          return BaseInput
          // break

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

  return {
    typeComponentRef,
    typeOptions,
    valueComponent,
    valueComponentRef
  }
}

// @vue/component
export default {
  name: 'base-inline-trigger-condition',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

