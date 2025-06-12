<template>
  <div class="base-flex-wrap" align-v="center">

    <base-input-chosen-one ref="nameComponentRef"
      :namespace="`${namespace}.name`"
      :options="nameOptions"
    />

    <component :is="valueComponent" ref="valueComponentRef"
      :namespace="`${namespace}.value`"
      :placeholder="valuePlaceholder"
    />

  </div>
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

import store from '@/store'
import { computed, nextTick, ref, unref, watch } from '@vue/composition-api'
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

  const nameComponentRef = ref(null)
  const nameOptions = Object.entries(store.getters[`$_fingerbank/environment`])
    .map(([text]) => ({ text, value: text }))
    .sort(({ text: textA }, { text: textB }) => textA.localeCompare(textB))


  watch( // when `name` is mutated
    () => unref(inputValue) && unref(inputValue).name,
    () => {
      const { isFocus = false } = nameComponentRef.value
      if (isFocus) { // and `name` isFocus
        onChange({ ...unref(inputValue), value: undefined }) // clear `value`

        nextTick(() => {
          const { doFocus = () => {} } = valueComponentRef.value || {}
          doFocus() // focus `value` component
        })
      }
    }
  )

  const valuePlaceholder = computed(() => {
    const { name } = unref(inputValue) || {}
    const { [name]: value } = store.getters[`$_fingerbank/environment`]
    return value
  })

  const valueComponentRef = ref(null)
  const valueComponent = computed(() => {
    switch (true) {
      case `${parseInt(unref(valuePlaceholder))}` == `${unref(valuePlaceholder)}`:
        return BaseInputNumber
        // break

      default:
        return BaseInput
    }
  })



  return {
    nameComponentRef,
    nameOptions,
    valueComponent,
    valueComponentRef,
    valuePlaceholder
  }
}

// @vue/component
export default {
  name: 'base-fingerbank-environment',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

