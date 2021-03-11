<template>
  <base-input-group
    :state="inputState"
    :invalid-feedback="inputInvalidFeedback"
    :valid-feedback="inputValidFeedback"
    :text="inputText"
    :isFocus="isFocus || isShown"
    :isLocked="isLocked"
  >
    <b-form-input ref="input"
      class="base-input"
      :disabled="isLocked"
      :readonly="inputReadonly"
      :placeholder="inputPlaceholder"
      :tabIndex="inputTabIndex"
      :type="inputType"
      :value="inputValue"
      @input="onInput"
      @change="onChange"
      @focus="onFocus"
      @blur="onBlur"
    />
    <template v-slot:append>
      <b-form-datepicker v-if="!isLocked"
        ref="datepickerRef"
        button-only right
        button-variant="light"
        menu-class="my-2"
        :locale="$i18n.locale"
        :state="inputState"
        :value="inputValue"
        @input="onInput"
        @change="onChange"
        @hidden="onHidden"
        @shown="onShown"
      >
        <template v-slot:button-content>
          <icon name="calendar-alt" />
        </template>
      </b-form-datepicker>
    </template>
  </base-input-group>
</template>
<script>
import { BaseInputGroup } from '@/components/new'

const components = {
  BaseInputGroup
}

import { ref } from '@vue/composition-api'
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

  min: {
    type: [Date, String]
  },
  max: {
    type: [Date, String]
  }
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
    onBlur,
    doFocus
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

  const datepickerRef = ref(null)
  const isShown = ref(false)
  const onShown = () => { isShown.value = true }
  const onHidden = () => { isShown.value = false }

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
    doFocus,

    // useInputValue
    inputValue: value,
    onInput,
    onChange,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,

    datepickerRef,
    isShown,
    onShown,
    onHidden
  }
}

// @vue/component
export default {
  name: 'base-input-group-date',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
