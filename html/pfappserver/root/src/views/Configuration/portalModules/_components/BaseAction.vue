<template>
  <div class="base-flex-wrap" align-v="center">

    <base-input-chosen-one ref="typeComponentRef"
      :namespace="`${namespace}.type`"
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
  BaseInputGroupDateTime,
  BaseInputGroupMultiplier,
  BaseInputNumber,
  BaseInputPassword,
  BaseInputChosenMultiple,
  BaseInputChosenOne
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputGroupDateTime,
  BaseInputGroupMultiplier,
  BaseInputNumber,
  BaseInputPassword,
  BaseInputChosenMultiple,
  BaseInputChosenOne
}

import { computed, inject, nextTick, ref, toRefs, unref, watch } from '@vue/composition-api'
import { pfActions as actions } from '@/globals/pfActions'
import {
  pfComponentType as componentType,
  pfFieldTypeComponent as fieldTypeComponent,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'
import { useInputMeta, useInputMetaProps, useNamespaceMetaAllowed } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = (props, context) => {

  const { namespace } = toRefs(props)

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

  const action = computed(() => {
    const { type } = unref(inputValue) || {}
    return actions[type]
  })

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
  })

  // meta `type` may contain sibling allowed_values for `value`
  //  @meta.actions.item.properties.type.allowed[*].siblings.type.allowed_values
  const meta = inject('meta', ref({}))
  const valueSiblingOptions = computed(() => {
    const allowed = useNamespaceMetaAllowed(`${namespace.value}.type`, meta)
    const type = allowed.find(item => {
      return item.value === inputValue.value.type
    })
    const { siblings: { type: { allowed_values } = {} } = {} } = type ||{}
    return allowed_values
  })

  const valueOptions = ref([])
  watch(
    action,
    () => {
      if (valueSiblingOptions.value) // meta `type` contains sibling allowed_values
        return valueOptions.value = valueSiblingOptions.value
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
    valueComponent,
    valueComponentRef,
    valueOptions
  }
}

// @vue/component
export default {
  name: 'base-action',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
