<template>
  <base-form-group
    class="form-group base-form-group-switch"
    :column-label="columnLabel"
    :content-cols="contentCols"
    :content-cols-sm="contentColsSm"
    :content-cols-md="contentColsMd"
    :content-cols-lg="contentColsLg"
    :content-cols-xl="contentColsXl"
    :label-class="labelClass"
    :label-cols="labelCols"
    :label-cols-sm="labelColsSm"
    :label-cols-md="labelColsMd"
    :label-cols-lg="labelColsLg"
    :label-cols-xl="labelColsXl"
    :text="text"
    :state="inputState"
    :invalid-feedback="inputInvalidFeedback"
    :valid-feedback="inputValidFeedback"
  >
    <base-input-switch :disabled="isLocked"
                       :size="size"
                       :onChange="onChange"
                       :value="inputValue"
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
import {useFormGroupProps} from '@/composables/useFormGroup'
import {useInput, useInputProps} from '@/composables/useInput'
import {useInputMeta, useInputMetaProps} from '@/composables/useMeta'
import {useInputValidator, useInputValidatorProps} from '@/composables/useInputValidator'
import {
  getFormNamespace,
  setFormNamespace,
  useInputValue,
  useInputValueProps
} from '@/composables/useInputValue'
import BaseFormGroup from './BaseFormGroup'
import BaseInputSwitch from './BaseInputSwitch'
import {computed, inject, unref} from '@vue/composition-api';

const components = {
  BaseFormGroup,
  BaseInputSwitch
}

export const props = {
  enabledValue: {
    type: [String, Number, Boolean],
    default: true
  },
  disabledValue: {
    type: [String, Number, Boolean],
    default: false
  },
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },
  isFocus: {
    default: false,
    type: Boolean
  },
  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,
}

export const setup = (props, context) => {
  const metaProps = useInputMeta(props, context)

  const {
    tabIndex,
    text,
    isLocked,
    onBlur
  } = useInput(metaProps, context)

  const {
    value,
    onInput
  } = useInputValue(metaProps, context)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value)

  const form = inject('form')
  const onChange = (switchValue) => {
    if (switchValue) {
      setFormNamespace(props.namespace.split('.'), unref(form), props.enabledValue)
    } else {
      setFormNamespace(props.namespace.split('.'), unref(form), props.disabledValue)
    }
  }
  const inputValue = computed(() =>
    getFormNamespace(props.namespace.split('.'), unref(form)) === props.enabledValue
  )

  return {
    // useInput
    inputTabIndex: tabIndex,
    inputText: text,
    inputValue,
    onChange,
    isLocked,
    onBlur,
    onInput,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback
  }
}

// @vue/component
export default {
  name: 'base-form-group-switch',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
.base-form-group-switch {
  .input-group {
    padding-bottom: 0px !important;
  }
}
</style>
