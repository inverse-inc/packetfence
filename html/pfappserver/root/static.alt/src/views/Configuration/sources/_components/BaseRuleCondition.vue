<template>
  <b-row class="w-100 mx-0 mb-1 px-0" align-v="center" no-gutters>
    <b-col sm="4" align-self="start">

      <base-input-select-one ref="attributeComponentRef"
        :namespace="`${namespace}.attribute`"
      />

    </b-col>
    <b-col sm="3" align-self="start" class="pl-1">

      <base-input-select-one ref="operatorComponentRef" v-if="attributeValue"
        :namespace="`${namespace}.operator`"
        :options="operatorOptions"
      />

    </b-col>
    <b-col sm="5" align-self="start" class="pl-1">

      <component :is="valueComponent" ref="valueComponentRef" v-if="operatorValue"
        :namespace="`${namespace}.value`"
        v-bind="valueBind"
      />

    </b-col>
  </b-row>
</template>
<script>
import { computed, nextTick, ref, toRefs, unref, watch } from '@vue/composition-api'
import {
  pfComponentType as componentType,
  pfFieldTypeComponent as fieldTypeComponent,
  pfFieldTypeOperators as fieldTypeOperators,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'
import {
  BaseInput,
  BaseInputGroupMultiplier,
  BaseInputNumber,
  BaseInputPassword,
  BaseInputRange,
  BaseInputSelectMultiple,
  BaseInputSelectOne
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputGroupMultiplier,
  BaseInputNumber,
  BaseInputPassword,
  BaseInputRange,
  BaseInputSelectMultiple,
  BaseInputSelectOne
}

import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import { useNamespaceMetaAllowed } from '@/composables/useMeta'

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
    value: inputValue,
    onChange
  } = useInputValue(metaProps, context)

  const attributeComponentRef = ref(null)
  const operatorComponentRef = ref(null)
  const valueComponentRef = ref(null)

  watch( // when `attribute` is mutated
    () => unref(inputValue) && unref(inputValue).attribute,
    () => {
      const { isFocus = false } = attributeComponentRef.value
      if (isFocus) { // and `attribute` isFocus
        onChange({ ...unref(inputValue), operator: undefined, value: undefined }) // clear `operator` and `value`

        nextTick(() => {
          const { doFocus = () => {} } = operatorComponentRef.value || {}
          doFocus() // focus `operator` component
        })
      }
    }
  )

  watch( // when `operator` is mutated
    () => unref(inputValue) && unref(inputValue).operator,
    () => {
      const { isFocus = false } = operatorComponentRef.value
      if (isFocus) { // and `operator` isFocus
        onChange({ ...unref(inputValue), value: undefined }) // clear `value`

        nextTick(() => {
          const { doFocus = () => {} } = valueComponentRef.value || {}
          doFocus() // focus `value` component
        })
      }
    }
  )

  const attributes = computed(() => unref(useNamespaceMetaAllowed(`${unref(namespace)}.attribute`)))

  const attributeValue = computed(() => {
    const { attribute } = unref(inputValue) || {}
    return unref(attributes).find(a => a.value === attribute)
  })

  const operatorOptions = computed(() => {
    const { attributes: { 'data-type': type } = {} } = unref(attributeValue) || {}
    return (type && type in fieldTypeOperators)
      ? fieldTypeOperators[type]
      : []
  })

  const operatorValue = computed(() => {
    const { operator } = unref(inputValue) || {}
    return operator
  })

  const valueComponent = computed(() => {
    if (attributeValue.value) {
      const { attributes: { 'data-type': type } = {} } = unref(attributeValue) || {}
      const component = fieldTypeComponent[type]
      switch (component) {
        case componentType.SELECTMANY:
          return BaseInputSelectMultiple
          // break

        case componentType.SELECTONE:
          return BaseInputSelectOne
          // break

        case componentType.TIME:
          return BaseInput
          // break

        case componentType.SUBSTRING:
          return BaseInput
          // break

        default:
          // eslint-disable-next-line
          console.error(`Unhandled pfComponentType '${component}' for pfFieldType '${type}'`)
      }
    }
  })

  const valueBind = computed(() => {
    const { attributes: { 'data-type': type } = {} } = unref(attributeValue) || {}
    if (type && type in fieldTypeValues) {
      const options = fieldTypeValues[type]()
      if (0 in options && 'group' in options[0]) // grouped
        return { groupLabel: 'group', groupValues: 'items', options }
      else // non-grouped
        return { options }
    }
  })

  return {
    attributeComponentRef,
    attributeValue,

    operatorComponentRef,
    operatorOptions,
    operatorValue,

    valueComponentRef,
    valueComponent,
    valueBind
  }
}

// @vue/component
export default {
  name: 'base-rule-condition',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
