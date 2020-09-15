<template>
  <base-form-group
    :label-cols="labelCols"
    :column-label="columnLabel"
    :text="text"
    :disabled="disabled"
    :state="inputState"
    :invalid-feedback="inputInvalidFeedback"
    :valid-feedback="inputValidFeedback"
  >
    <base-input-range
      class="base-form-group-toggle"
      step="1"
      min="0"
      :max="max"
      :disabled="isLocked"
      :size="size"
      :state="inputState"
      :tabIndex="inputTabIndex"
      :value="inputValue"
      @change="onChange"
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
import { useInputMeta, useInputMetaProps } from '@/composables/useInputMeta'
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
    placeholder,
    tabIndex,
    text,
    isFocus,
    isLocked,
    onFocus,
    onBlur
  } = useInput(metaProps, context)

  const valueProps = useInputValue(metaProps, context)
  const {
    value,
    onChange,
    max
  } = useInputValueToggle(valueProps, props, context)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value)

  return {
    // useInput
    inputPlaceholder: placeholder,
    inputTabIndex: tabIndex,
    inputText: text,
    isFocus,
    isLocked,
    onFocus,
    onBlur,

    // useInputValue
    inputValue: value,
    onChange,
    max,

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
  /* match height of input element to vertically align w/ form-group label */
  min-height: $input-height;
  display: flex;
  align-items: center;
  .base-input-range {
    &[index],
    &[index="0"] {
      --range-background-color: #adb5bd; /* default unchecked background-color */
    }
    &[index="1"] {
      --range-background-color: var(--primary); /* default checked background-color */
    }
  }
/*
  .pf-form-range-toggle-label {
    display: inline-flex;
    align-items: center;
    padding-top: calc(#{$input-padding-y} + #{$input-border-width});
    vertical-align: middle;
    margin: 0;
    user-select: none;
  }
*/
}
</style>
