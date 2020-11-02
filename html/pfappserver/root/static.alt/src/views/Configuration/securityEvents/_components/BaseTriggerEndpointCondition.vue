<template>
  <div class="base-trigger-endpoint-condition base-flex-wrap" align-v="center">

    <base-input-chosen-one ref="typeComponentRef"
    :namespace="`${namespace}.type`"
      :options="typeOptions"
    />

    <component :is="valueComponent" ref="valueComponentRef"
      :namespace="`${namespace}.value`"
      :options="valueOptions"
    />

  </div>
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
  pfFieldTypeComponent as fieldTypeComponent
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
<style lang="scss">
.base-trigger-endpoint-condition {
  .btn {
    margin: 0.25rem !important;
  }
}
</style>
