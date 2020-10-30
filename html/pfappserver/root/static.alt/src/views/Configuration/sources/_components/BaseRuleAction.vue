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
  BaseInputGroupMultiplier,
  BaseInputNumber,
  BaseInputPassword,
  BaseInputRange,
  BaseInputChosenMultiple,
  BaseInputChosenOne
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputGroupMultiplier,
  BaseInputNumber,
  BaseInputPassword,
  BaseInputRange,
  BaseInputChosenMultiple,
  BaseInputChosenOne
}

import { computed, inject, nextTick, ref, unref, watch } from '@vue/composition-api'
import {
  pfComponentType as componentType,
  pfFieldTypeComponent as fieldTypeComponent,
  pfFieldTypeValues as fieldTypeValues
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
  const valueComponentRef = ref(null)

  watch( // when `type` is mutated
    () => unref(inputValue) && unref(inputValue).type,
    () => {
      const { isFocus = false } = typeComponentRef.value
      if (isFocus) { // and `type` isFocus
        const { ['default']: _default } = unref(action)
        if (_default)
          onChange({ ...unref(inputValue), value: _default }) // default `value` (eg: mark_as_sponsor = 1)
        else {
          onChange({ ...unref(inputValue), value: undefined }) // clear `value`

          nextTick(() => {
            const { doFocus = () => {} } = valueComponentRef.value || {}
            doFocus() // focus `value` component
          })
        }
      }
    }
  )

  const actions = inject('actions', [])

  const action = computed(() => {
    const { type } = unref(inputValue) || {}
    const actionIndex = unref(actions).findIndex(action => action.value && action.value === type)
    if (actionIndex >= 0)
      return unref(actions)[actionIndex]
    return undefined
  })

  const typeOptions = computed(() => unref(actions).map(action => {
    const { text, value } = action
    return { text, value }
  }))

  const valueComponent = computed(() => {
    if (action.value) {
      const { types = [] } = action.value
      for (let t = 0; t < types.length; t++) {
        let type = types[t]
        let component = fieldTypeComponent[type]
        switch (component) {
          case componentType.SELECTMANY:
            return BaseInputChosenMultiple
            // break

          case componentType.SELECTONE:
            return BaseInputChosenOne
            // break

          case componentType.DATETIME:
            return BaseInput
            // break

          case componentType.PREFIXMULTIPLIER:
            return BaseInputGroupMultiplier
            // break

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
    }
  })

  const valueOptions = ref([])
  watch(
    action,
    () => {
      valueOptions.value = []
      if (action.value) {
        let { options = [] } = action.value
        if (options.length > 0) {
          valueOptions.value = options
          // return
        }
        const { types = [] } = action.value
        for (let t = 0; t < types.length; t++) {
          let type = types[t]
          if (type in fieldTypeValues) {
            Promise.resolve(fieldTypeValues[type]()).then(options => {
              const values = valueOptions.value.map(option => option.value)
              for (let option of options) {
                if (!values.includes(option.value))
                  valueOptions.value.push(option)
              }
            })
          }
        }
      }
    },
    { immediate: true }
  )

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
  name: 'base-rule-action',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

