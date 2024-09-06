<template>
  <b-form-group ref="form-group"
    class="base-form-group"
    :class="{
      'mb-0': !columnLabel
    }"
    :content-cols="contentCols"
    :content-cols-sm="contentColsSm"
    :content-cols-md="contentColsMd"
    :content-cols-lg="contentColsLg"
    :content-cols-xl="contentColsXl"
    :label="columnLabel"
    :label-class="labelClass"
    :label-cols="labelCols"
    :label-cols-sm="labelColsSm"
    :label-cols-md="labelColsMd"
    :label-cols-lg="labelColsLg"
    :label-cols-xl="labelColsXl"
    :state="inputState"
  >
    <b-input-group
      :class="{
        'is-focus': isFocus,
        'is-blur': !isFocus,
        'is-valid': inputState === true,
        'is-invalid': inputState === false
      }"
    >
      <b-form-input ref="input"
        class="base-form-group-input"
        :data-namespace="namespace"
        :disabled="isLocked"
        :readonly="inputReadonly"
        :state="inputState"
        :placeholder="inputPlaceholder"
        :tabIndex="inputTabIndex"
        :type="inputType"
        :value="inputValue"
        @input="onInput"
        @change="onChange"
        @focus="onFocus"
        @blur="onBlur"
        v-on="$listeners"
      />
      <template v-slot:prepend v-if="$slots.prepend || inputPlaceholder">
        <slot name="prepend"></slot>
        <b-button v-if="isDefault && isEmpty"
          class="input-group-text"
          :disabled="true"
          tabIndex="-1"
          v-b-tooltip.hover.left.d300 :title="$t('A default value is provided if this field is not defined.')"
        >
          <icon ref="icon-default"
            name="stamp" scale="0.75"
          />
        </b-button>
      </template>
      <template v-slot:append v-if="$slots.append || isLocked">
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
    <template v-slot:description v-if="inputText || inputApiFeedback">
      <div v-if="inputApiFeedback" v-html="inputApiFeedback" class="text-warning"/>
      <div v-if="inputText" v-html="inputText"/>
    </template>
    <template v-slot:invalid-feedback v-if="inputInvalidFeedback">
      <div v-html="inputInvalidFeedback"/>
    </template>
    <template v-slot:valid-feedback v-if="inputValidFeedback">
      <div v-html="inputValidFeedback"/>
    </template>
  </b-form-group>
</template>
<script>
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
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
    type,
    isDefault,
    isFocus,
    isLocked,
    onFocus,
    onBlur,
    doFocus
  } = useInput(metaProps, context)

  const {
    value,
    onInput,
    onChange,
    isEmpty
  } = useInputValue(metaProps, context)

  const {
    state,
    invalidFeedback,
    validFeedback,
    apiFeedback
  } = useInputValidator(metaProps, value)

  return {
    // useInput
    inputPlaceholder: placeholder,
    inputReadonly: readonly,
    inputTabIndex: tabIndex,
    inputText: text,
    inputType: type,
    isDefault,
    isFocus,
    isLocked,
    onFocus,
    onBlur,
    doFocus,

    // useInputValue
    inputValue: value,
    isEmpty,
    onInput,
    onChange,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,
    inputApiFeedback: apiFeedback
  }
}

// @vue/component
export default {
  name: 'base-form-group-input',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.base-form-group {
  .input-group > * {
    &:first-child {
      border-top-left-radius: $border-radius !important;
      border-bottom-left-radius: $border-radius !important;
    }
    &:not(:first-child) {
      border-top-left-radius: 0 !important;
      border-bottom-left-radius: 0 !important;
    }
    &:last-child {
      border-top-right-radius: $border-radius !important;
      border-bottom-right-radius: $border-radius !important;
    }
    &:not(:last-child) {
      border-top-right-radius: 0 !important;
      border-bottom-right-radius: 0 !important;
    }
  }
}
</style>
