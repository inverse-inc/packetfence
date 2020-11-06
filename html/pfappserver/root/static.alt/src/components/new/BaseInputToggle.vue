<template>
  <div style="flex-grow: 100;">
    <base-input-range
      class="base-input-toggle"
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
      :tooltip="inputTooltip"
      :label="inputLabel"
      :label-left="labelLeft"
      :label-right="labelRight"
      @input="onInput"
      @focus="onFocus"
      @blur="onBlur"
    />
    <small v-if="inputText"
      v-html="inputText"
    />
    <small v-if="inputInvalidFeedback"
      class="invalid-feedback"
      v-html="inputInvalidFeedback"
    />
    <small v-if="inputValidFeedback"
      class="valid-feedback"
      v-html="inputValidFeedback"
    />
  </div>
</template>
<script>
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import { useInputValueToggle, useInputValueToggleProps } from '@/composables/useInputValueToggle'
import BaseInputRange from './BaseInputRange'

const components = {
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
  name: 'base-input-toggle',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script><style lang="scss">
.base-input-toggle {
  /* match height of input element to vertically align w/ form-group label */
  min-height: $input-height;
  display: flex;
  align-items: center;
  justify-content: inherit;
}
</style>
