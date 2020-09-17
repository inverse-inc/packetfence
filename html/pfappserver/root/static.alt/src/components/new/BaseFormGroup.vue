<template>
  <b-form-group ref="form-group"
    class="base-form-group"
    :class="{
      'mb-0': !columnLabel
    }"
    :state="inputState"
    :labelCols="labelCols"
    :label="columnLabel"
  >
    <template v-slot:invalid-feedback>
      {{ inputInvalidFeedback }}
    </template>
    <template v-slot:valid-feedback>
      {{ inputValidFeedback }}
    </template>
    <b-input-group
      :class="{
'foobar': true,
        'is-valid': inputState === true,
        'is-invalid': inputState === false
      }"
    >
      <!-- Proxy slots -->
      <template v-slot:default>
        <slot/>
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
    <b-form-text v-if="inputText" v-html="inputText"></b-form-text>
  </b-form-group>
</template>
<script>
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useInputMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

export const props = {
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
    isLocked
  } = useInput(metaProps, context)

  const {
    value
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
    isLocked,

    // useInputValue
    inputValue: value,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback
  }
}

// @vue/component
export default {
  name: 'base-form-group',
  inheritAttrs: false,
  props,
  setup
}
</script>
