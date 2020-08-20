<template>
  <b-form-group ref="form-group"
    class="base-form-group"
    :class="{
      'mb-0': !formGroupLabel
    }"
    :state="inputState"
    :labelCols="formGroupLabelCols"
    :label="formGroupLabel"
  >
    <template v-slot:invalid-feedback>
      {{ inputInvalidFeedback }}
    </template>
    <template v-slot:valid-feedback>
      {{ inputValidFeedback }}
    </template>
    <b-input-group
      :class="{
        'is-valid': inputState === true,
        'is-invalid': inputState === false
      }"
    >
      <!-- Proxy slots -->
      <template v-slot:default>
        <slot name="default"></slot>
      </template>
      <template v-slot:prepend>
        <slot name="prepend"></slot>
      </template>
      <template v-slot:append>
        <slot name="append"></slot>
        <b-button v-if="isLocked"
          class="input-group-text"
          :disabled="true"
          tabIndex="-1"
        >
          <icon ref="icon-lock"
            name="lock"
          />
        </b-button>
      </template>
    </b-input-group>
    <b-form-text v-if="formGroupText" v-html="formGroupText"></b-form-text>
  </b-form-group>
</template>
<script>
import { useFormGroup, useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputValidation, useInputValidationProps } from '@/composables/useInputValidation'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

export const props = {
  ...useFormGroupProps,
  ...useInputProps,
  ...useInputValidationProps,
  ...useInputValueProps
}

// @vue/component
export default {
  name: 'base-form-group',
  inheritAttrs: false,
  props,
  setup(props, context) {
    const {
      columnLabel,
      labelCols,
      text
    } = useFormGroup(props, context)

    const {
      placeholder,
      readonly,
      tabIndex,
      type,
      isFocus,
      isLocked,
      onFocus,
      onBlur
    } = useInput(props, context)

    const {
      value,
      onInput,
      onChange
    } = useInputValue(props, context)

    const {
      state,
      invalidFeedback,
      validFeedback
    } = useInputValidation(props, value)

    return {
      // useFormGroup
      formGroupLabel: columnLabel,
      formGroupLabelCols: labelCols,
      formGroupText: text,

      // useInput
      inputReadonly: readonly,
      inputPlaceholder: placeholder,
      inputTabIndex: tabIndex,
      inputType: type,
      isFocus,
      isLocked,
      onFocus,
      onBlur,

      // useInputValidation
      inputState: state,
      inputInvalidFeedback: invalidFeedback,
      inputValidFeedback: validFeedback,

      // useInputValue
      inputValue: value,
      onInput,
      onChange
    }
  }
}
</script>
