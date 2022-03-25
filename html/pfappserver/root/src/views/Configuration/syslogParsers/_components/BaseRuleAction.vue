<template>
  <div class="base-flex-wrap" align-v="center">

    <base-input-chosen-one ref="apiMethodComponentRef"
      :namespace="`${namespace}.api_method`"
      :options="apiMethodOptions"
    />

    <component :is="apiParametersComponent" ref="apiParametersComponentRef"
      :namespace="`${namespace}.api_parameters`"
      :options="apiParametersOptions"
    />

  </div>
</template>
<script>
import {
  BaseInput,
  BaseInputGroupDateTime,
  BaseInputGroupMultiplier,
  BaseInputNumber,
  BaseInputPassword,
  BaseInputRange,
  BaseInputChosenMultiple,
  BaseInputChosenOne
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputGroupDateTime,
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

  const apiMethodComponentRef = ref(null)
  const apiParametersComponentRef = ref(null)

  watch( // when `api_method` is mutated
    () => unref(inputValue) && unref(inputValue).api_method,
    () => {
      const { isFocus = false } = apiMethodComponentRef.value
      if (isFocus) { // and `api_method` isFocus
        const { ['default']: _default, siblings: { api_parameters: { ['default']: apiParametersDefault } = {} } = {} } = unref(action)
        if (_default)
          onChange({ ...unref(inputValue), api_parameters: _default }) // default `api_parameters` (eg: mark_as_sponsor = 1)
        else {
          onChange({ ...unref(inputValue), api_parameters: apiParametersDefault }) // set `api_parameters`

          nextTick(() => {
            const { doFocus = () => {} } = apiParametersComponentRef.value || {}
            doFocus() // focus `api_parameters` component
          })
        }
      }
    }
  )

  const actions = inject('actions', [])

  const action = computed(() => {
    const { api_method } = unref(inputValue) || {}
    const actionIndex = unref(actions).findIndex(action => action.value && action.value === api_method)
    if (actionIndex >= 0)
      return unref(actions)[actionIndex]
    return undefined
  })

  const apiMethodOptions = computed(() => unref(actions).map(action => {
    const { text, value } = action
    return { text, value }
  }))

  const apiParametersComponent = computed(() => {
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
            return BaseInputGroupDateTime
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
    return undefined
  })

  const apiParametersOptions = ref([])
  watch(
    action,
    () => {
      apiParametersOptions.value = []
      if (action.value) {
        let { options = [] } = action.value
        if (options.length > 0) {
          apiParametersOptions.value = options
          // return
        }
        const { types = [] } = action.value
        for (let t = 0; t < types.length; t++) {
          let type = types[t]
          if (type in fieldTypeValues) {
            Promise.resolve(fieldTypeValues[type]()).then(options => {
              const values = apiParametersOptions.value.map(option => option.value)
              for (let option of options) {
                if (!values.includes(option.value))
                  apiParametersOptions.value.push(option)
              }
            })
          }
        }
      }
    },
    { immediate: true }
  )

  return {
    apiMethodComponentRef,
    apiMethodOptions,
    apiParametersComponent,
    apiParametersComponentRef,
    apiParametersOptions
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
