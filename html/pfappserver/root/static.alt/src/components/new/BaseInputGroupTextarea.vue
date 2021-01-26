<template>
  <base-input-group
    :state="inputState"
    :invalid-feedback="inputInvalidFeedback"
    :valid-feedback="inputValidFeedback"
    :text="inputText"
    :isFocus="isFocus"
    :isLocked="isLocked"
  >
    <b-form-textarea ref="input"
      class="base-input"
      :disabled="isLocked"
      :readonly="inputReadonly"
      :placeholder="inputPlaceholder"
      :tabIndex="inputTabIndex"
      :value="inputValue"
      :rows="rows"
      :maxRows="maxRows"
      @input="onInput"
      @change="onChange"
      @focus="onFocus"
      @blur="onBlur"
    />
    <template v-slot:append v-if="$slots.append">
      <slot name="append"></slot>
    </template>
  </base-input-group>
</template>
<script>
import BaseInputGroup from './BaseInputGroup'

const components = {
  BaseInputGroup
}

import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

export const props = {
  maxRows: {
    type: [Number, String]
  },
  rows: {
    type: [Number, String],
    default: 3
  },
  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps
}

export const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    placeholder,
    readonly,
    tabIndex,
    text,
    type,
    isFocus,
    isLocked,
    onFocus,
    onBlur
  } = useInput(metaProps, context)

  const {
    value,
    onInput,
    onChange
  } = useInputValue(metaProps, context)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value)

  return {
    // useInput
    inputPlaceholder: placeholder,
    inputReadonly: readonly,
    inputTabIndex: tabIndex,
    inputText: text,
    inputType: type,
    isFocus,
    isLocked,
    onFocus,
    onBlur,

    // useInputValue
    inputValue: value,
    onInput,
    onChange,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback
  }
}

// @vue/component
export default {
  name: 'base-input-group-multiplier',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
