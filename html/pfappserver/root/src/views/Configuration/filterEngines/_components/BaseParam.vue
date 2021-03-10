<template>
  <div class="base-param base-flex-wrap" align-v="center">

    <base-input-chosen-one ref="typeComponentRef"
      :namespace="`${namespace}.type`"
    />

    <base-input ref="valueComponentRef"
      :namespace="`${namespace}.value`"
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

  const typeComponentRef = ref(null)
  const valueComponentRef = ref(null)

  const type = computed(() => {
    const { type } = inputValue.value || {}
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

  return {
    typeComponentRef,
    valueComponentRef
  }
}

// @vue/component
export default {
  name: 'base-param',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
.base-param {
  .btn {
    margin: 0.25rem !important;
  }
}
</style>
