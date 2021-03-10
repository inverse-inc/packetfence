<template>
  <div class="base-flex-wrap" align-v="center">

    <base-input-chosen-one ref="apiMethodComponentRef"
      :namespace="`${namespace}.api_method`"
    />

    <base-input ref="apiParametersComponentRef" v-if="apiMethodValue"
      :namespace="`${namespace}.api_parameters`"
      :placeholder="apiParametersPlaceholder"
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

import { computed, nextTick, ref, toRefs, unref, watch } from '@vue/composition-api'
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

  const apiMethodComponentRef = ref(null)
  const apiParametersComponentRef = ref(null)

  watch( // when `api_method` is mutated
    () => inputValue.value && inputValue.value.api_method,
    () => {
      const { isFocus = false } = apiMethodComponentRef.value
      if (isFocus) { // and `api_method` isFocus
        onChange({ ...inputValue.value, api_parameters: apiParametersPlaceholder.value  }) // set `api_parameters` from sibling default

        nextTick(() => {
          const { doFocus = () => {} } = apiParametersComponentRef.value || {}
          doFocus() // focus `api_parameters` component
        })
      }
    }
  )

  const apiMethods = computed(() => unref(useNamespaceMetaAllowed(`${namespace.value}.api_method`)))
  const apiMethodValue = computed(() => {
    const { api_method } = inputValue.value || {}
    if (apiMethods.value)
      return apiMethods.value.find(a => a.value === api_method)
  })
  const apiParametersPlaceholder = computed(() => {
    const { api_method } = inputValue.value || {}
    if (apiMethods.value) {
      const { sibling: { api_parameters: { ['default']: placeholder } = {} } = {} } = apiMethods.value.find(a => a.value === api_method) || {}
      return placeholder
    }
  })

  return {
    apiMethodComponentRef,
    apiMethodValue,

    apiParametersComponentRef,
    apiParametersPlaceholder
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
