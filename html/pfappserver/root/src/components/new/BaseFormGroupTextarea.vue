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
      <b-form-textarea ref="input"
        class="base-form-input"
        :data-namespace="namespace"
        :disabled="isLocked"
        :readonly="inputReadonly"
        :state="inputState"
        :placeholder="inputPlaceholder"
        :tabIndex="inputTabIndex"
        :type="inputType"
        :value="inputValue"
        :rows="inputRows"
        :maxRows="maxRows"
        @input="onInput"
        @change="onChange"
        @focus="onFocus"
        @blur="onBlur"
      />
      <template v-slot:prepend v-if="$slots.prepend">
        <slot name="prepend"></slot>
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
import { computed, toRefs } from '@vue/composition-api'
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
  ...useInputValueProps,

  maxRows: {
    type: [Number, String]
  },
  rows: {
    type: [Number, String],
    default: 3
  },
  autoFit: {
    type: Boolean
  }
}

export const setup = (props, context) => {

  const {
    rows,
    autoFit
  } = toRefs(props)

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
    validFeedback,
    apiFeedback
  } = useInputValidator(metaProps, value)

  const inputRows = computed(() => {
    if (autoFit.value) {
      const r = [...(value.value || '')].filter(c => c === '\n').length + 1
      return Math.max(rows.value, r)
    }
    return rows.value
  })


  return {
    // useInput
    inputPlaceholder: placeholder,
    inputReadonly: readonly,
    inputRows,
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
    inputValidFeedback: validFeedback,
    inputApiFeedback: apiFeedback
  }
}

// @vue/component
export default {
  name: 'base-form-group-textarea',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.base-form-group {
  textarea {
    min-height: $input-height;
  }
}
</style>
