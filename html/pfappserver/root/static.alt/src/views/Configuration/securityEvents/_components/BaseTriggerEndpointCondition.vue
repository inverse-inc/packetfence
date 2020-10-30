<template>
  <b-row class="w-100 mx-0 mb-1 px-0 py-2" align-v="center" no-gutters>
    <b-col sm="6" align-self="start">

      <base-input-chosen-one ref="typeComponentRef"
        :namespace="`${namespace}.type`"
        :options="typeOptions"
      />

    </b-col>
    <b-col sm="6" align-self="start" class="pl-1">

      <component :is="valueComponent" ref="valueComponentRef"
        :namespace="`${namespace}.value`"
        :options="valueOptions"
      />

    </b-col>
  </b-row>
</template>
<script>
import {
  BaseInput,
  BaseInputChosenOne
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputChosenOne
}

import { computed, inject, nextTick, ref, unref, watch } from '@vue/composition-api'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import { useNamespaceMetaAllowed } from '@/composables/useMeta'
import {
  pfComponentType as componentType,
  pfFieldTypeComponent as fieldTypeComponent,
  pfFieldTypeValues as fieldTypeValues,


  pfFieldType as fieldType
} from '@/globals/pfField'
import {
  triggerCategories,
  triggerFields
} from '../config'

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
  const valueComponentRef = ref(null)

  const type = computed(() => {
    const { type } = inputValue.value
    return type
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

  const meta = inject('meta', ref({}))
  const valueOptions = ref([])
  watch(type, () => {
    valueOptions.value = useNamespaceMetaAllowed(`triggers.0.${type.value}`, meta)
  }, { immediate: true })

  const typeOptions = Object.keys(triggerFields)
    .filter(field => {
      const { category } = triggerFields[field]
      return category === triggerCategories.ENDPOINT
    })
    .map(value => {
      const { text, types } = triggerFields[value] || {}
      return { value, text, types }
    })

  const valueComponent = computed(() => {
    const { type } = unref(inputValue) || {}
    const { types = [] } = triggerFields[type] || {}
    for (let t = 0; t < types.length; t++) {
      let type = types[t]
      let component = fieldTypeComponent[type]
      switch (component) {
        case componentType.SELECTONE:
          return BaseInputChosenOne
          // break

        case componentType.SUBSTRING:
          return BaseInput
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
    valueComponentRef,
    valueOptions
  }
}

// @vue/component
export default {
  name: 'base-trigger-endpoint-condition',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
