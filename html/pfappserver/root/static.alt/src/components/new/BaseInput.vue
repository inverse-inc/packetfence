<template>
  <fragment>
    <b-form-input ref="input"
      class="base-input"
      :class="{
        'is-focus': isFocus,
        'is-blur': !isFocus
      }"
      :disabled="isLocked"
      :readonly="inputReadonly"
      :state="stateMapped"
      :placeholder="inputPlaceholder"
      :tabIndex="inputTabIndex"
      :type="inputType"
      :value="inputValue"
      @input="onInput"
      @change="onChange"
      @focus="onFocus"
      @blur="onBlur"
    />
    <small v-if="inputText"
      v-html="inputText"
    />
    <small v-if="stateInvalidFeedback"
      class="invalid-feedback"
      v-html="stateInvalidFeedback"
    />
    <small v-if="stateValidFeedback"
      class="valid-feedback"
      v-html="stateValidFeedback"
    />
  </fragment>
</template>
<script>
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputValidation, useInputValidationProps } from '@/composables/useInputValidation'

export const props = {
  ...useInputProps,
  ...useInputValidationProps
}

export const setup = (props, context) => {
  const {
    value,
    placeholder,
    readonly,
    tabIndex,
    text,
    type,
    isFocus,
    isLocked,
    onInput,
    onChange,
    onFocus,
    onBlur
  } = useInput(props, context)

  const {
    stateMapped,
    invalidFeedback,
    validFeedback
  } = useInputValidation(props, context)

  return {
    // useInput
    inputValue: value,
    inputReadonly: readonly,
    inputPlaceholder: placeholder,
    inputTabIndex: tabIndex,
    inputText: text,
    inputType: type,
    isFocus,
    isLocked,
    onInput,
    onChange,
    onFocus,
    onBlur,

    // useInputValidation
    stateMapped,
    stateInvalidFeedback: invalidFeedback,
    stateValidFeedback: validFeedback
  }
}

// @vue/component
export default {
  name: 'base-input',
  inheritAttrs: false,
  props,
  setup
}
</script>
