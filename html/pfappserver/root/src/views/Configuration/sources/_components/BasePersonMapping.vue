<template>
  <b-row class="w-100 mx-0 mb-1 px-0" align-v="center" no-gutters>
    <b-col sm="6" align-self="start">

      <base-input-chosen-one ref="personFieldComponentRef"
        :namespace="`${namespace}.person_field`"/>

    </b-col>
    <b-col sm="6" align-self="start" class="pl-1">

      <base-input ref="openidFieldComponentRef"
        :namespace="`${namespace}.openid_field`"/>

    </b-col>
  </b-row>
</template>
<script>
import {
  BaseInput,
  BaseInputChosenOne
} from '@/components/new/'

const components = {
  BaseInput,
  BaseInputChosenOne
}

import { nextTick, ref, unref, watch } from '@vue/composition-api'
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

  const personFieldComponentRef = ref(null)
  const openidFieldComponentRef = ref(null)

  watch( // when `person_field` is mutated
    () => unref(inputValue) && unref(inputValue).person_field,
    () => {
      const { isFocus = false } = personFieldComponentRef.value
      if (isFocus) { // and `person_field` isFocus
        onChange({ ...unref(inputValue), openid_field: undefined }) // clear `openid_field`

        nextTick(() => {
          const { doFocus = () => {} } = openidFieldComponentRef.value || {}
          doFocus() // focus `openid_field` component
        })
      }
    }
  )

  return {
    personFieldComponentRef,
    openidFieldComponentRef
  }
}

// @vue/component
export default {
  name: 'base-person-mapping',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
