<template>
  <div class="base-flex-wrap" align-v="center">

    <base-input-chosen-one ref="typeComponentRef"
      :namespace="`${namespace}.type`"
      :options="typeOptions"
    />

    <component :is="matchComponent" :key="inputValue.type" ref="matchComponentRef"
      :namespace="`${namespace}.match`"
      :options="matchOptions"
      v-bind="matchProps"
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

import { computed, nextTick, ref, unref, watch } from '@vue/composition-api'
import {
  pfComponentType as componentType,
  pfFieldTypeComponent as fieldTypeComponent,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import { pfFilters } from '@/globals/pfFilters'

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
  const matchComponentRef = ref(null)

  watch( // when `type` is mutated
    () => unref(inputValue) && unref(inputValue).type,
    () => {
      const { isFocus = false } = typeComponentRef.value
      if (isFocus) { // and `type` isFocus
        const { ['default']: _default } = unref(filter)
        if (_default)
          onChange({ ...unref(inputValue), value: _default }) // default `match` (eg: mark_as_sponsor = 1)
        else {
          onChange({ ...unref(inputValue), value: undefined }) // clear `match`

          nextTick(() => {
            const { doFocus = () => {} } = matchComponentRef.value || {}
            doFocus() // focus `match` component
          })
        }
      }
    }
  )

  const filters = Object.keys(pfFilters).map(key => pfFilters[key])

  const filter = computed(() => {
    const { type } = unref(inputValue) || {}
    const filterIndex = unref(filters).findIndex(filter => filter.value && filter.value === type)
    if (filterIndex >= 0)
      return unref(filters)[filterIndex]
    return undefined
  })

  const typeOptions = computed(() => unref(filters).map(filter => {
    const { text, value } = filter
    return { text, value }
  }))

  const matchComponent = computed(() => {
    if (filter.value) {
      const { types = [] } = filter.value
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

  const matchOptions = ref([])
  watch(
    filter,
    () => {
      matchOptions.value = []
      if (filter.value) {
        let { options = [] } = filter.value
        if (options.length > 0) {
          matchOptions.value = options
          // return
        }
        const { types = [] } = filter.value
        for (let t = 0; t < types.length; t++) {
          let type = types[t]
          if (type in fieldTypeValues) {
            Promise.resolve(fieldTypeValues[type]()).then(options => {
              const values = matchOptions.value.map(option => option.value)
              for (let option of options) {
                if (!values.includes(option.value))
                  matchOptions.value.push(option)
              }
            })
          }
        }
      }
    },
    { immediate: true }
  )

  const matchProps = computed(() => {
    const { props } = filter.value || {}
    return props
  })

  return {
    inputValue,
    typeComponentRef,
    typeOptions,
    matchComponent,
    matchComponentRef,
    matchOptions,
    matchProps
  }
}

// @vue/component
export default {
  name: 'base-filter',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
