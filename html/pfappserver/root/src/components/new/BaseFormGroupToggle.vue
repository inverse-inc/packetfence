<template>
  <base-form-group
    class="form-group base-form-group-toggle"
    :label-class="labelClass"
    :label-cols="labelCols"
    :column-label="columnLabel"
    :text="text"
    :state="inputState"
    :invalid-feedback="inputInvalidFeedback"
    :valid-feedback="inputValidFeedback"
  >
    <base-input-range
      class="base-input-range-toggle"
      step="1"
      min="0"
      :max="inputMax"
      :disabled="isLocked"
      :hints="hints"
      :size="size"
      :state="inputState"
      :tabIndex="inputTabIndex"
      :value="inputValue"
      :color="inputColor"
      :icon="inputIcon"
      :label="inputLabel"
      :label-left="labelLeft"
      :label-right="labelRight"
      @input="onInput"
      @focus="onFocus"
      @blur="onBlur"
    />
    <template v-slot:prepend v-if="$slots.prepend">
      <slot name="prepend"></slot>
    </template>
    <template v-slot:append v-if="$slots.append">
      <slot name="append"></slot>
    </template>
  </base-form-group>
</template>
<script>
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import { useInputValueToggle, useInputValueToggleProps } from '@/composables/useInputValueToggle'
import BaseFormGroup from './BaseFormGroup'
import BaseInputRange from './BaseInputRange'

const components = {
  BaseFormGroup,
  BaseInputRange
}

export const props = {
  labelLeft: {
    type: Boolean
  },
  labelRight: {
    type: Boolean
  },
  max: {
    type: [Number, String],
    default: 1
  },
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },
  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,
  ...useInputValueToggleProps
}

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
    value,
    onInput,
    max,
    label,
    color,
    icon,
    tooltip
  } = useInputValueToggle(valueProps, props, context)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value)

  return {
    // useInput
    inputTabIndex: tabIndex,
    inputText: text,
    isLocked,
    onFocus,
    onBlur,

    // useInputValue
    inputValue: value,
    onInput,
    inputMax: max,
    inputLabel: label,
    inputColor: color,
    inputIcon: icon,
    inputTooltip: tooltip,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback
  }
}

// @vue/component
export default {
  name: 'base-form-group-toggle',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
.base-form-group-toggle {
  .input-group {
    padding-bottom: 0px !important;
  }
}
.base-input-range-toggle {
  display: flex;
  align-items: top;
}
</style>
