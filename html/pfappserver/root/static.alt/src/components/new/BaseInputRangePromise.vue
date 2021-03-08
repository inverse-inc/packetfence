<template>
  <base-input-range
    class="base-form-group-toggle"
    step="1"
    min="0"
    max="1"
    :disabled="isLocked"
    :hints="hints"
    :size="size"
    :tabIndex="inputTabIndex"
    :value="inputValue"
    :color="inputColor"
    :icon="inputIcon"
    :label="inputLabel"
    @input="onInput"
    @focus="onFocus"
    @blur="onBlur"
  />
</template>
<script>
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import { useInputValueToggle, useInputValueToggleProps } from '@/composables/useInputValueToggle'
import BaseFormGroup from './BaseFormGroup'
import BaseInputRange from './BaseInputRange'

const components = {
  BaseFormGroup,
  BaseInputRange
}

export const props = {
  options: {
    type: Array,
    default: () => ([
      { value: 'disabled', color: 'var(--danger)', tooltip: 'E' },
      { value: 'enabled', color: 'var(--success)', tooltop: 'D' }
    ])
  },
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },
  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValueProps,
  ...useInputValueToggleProps
}

import { ref, toRefs, watch } from '@vue/composition-api'

export const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    tabIndex,
    text,
    isLocked,
    onFocus,
    onBlur
  } = useInput(metaProps, context)

  const valueProps = useInputValue(metaProps, context)

  const {
    value
  } = toRefs(metaProps)

  const onInput = () => {
    // console.log('onInput', newValue)
  }


  const {
    //value,
    //onInput,
    max,
    label,
    color,
    icon,
    tooltip
  } = useInputValueToggle(valueProps, props, context)

  const inputValue = ref(undefined)
  watch(value, () => { // v-model mutation
    inputValue.value = value.value
  }, { immediate: true })


  return {
    // useInput
    inputTabIndex: tabIndex,
    inputText: text,
    isLocked,
    onFocus,
    onBlur,

    // useInputValue
    inputValue,
    onInput,
    inputMax: max,
    inputLabel: label,
    inputColor: color,
    inputIcon: icon,
    inputTooltip: tooltip

  }
}

// @vue/component
export default {
  name: 'base-input-range-promise',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
.base-form-group-toggle {
  /* match height of input element to vertically align w/ form-group label */
  min-height: $input-height;
  display: flex;
  align-items: center;
}
</style>
