<template>
  <base-input-group
    :state="inputState"
    :invalid-feedback="inputInvalidFeedback"
    :valid-feedback="inputValidFeedback"
    :text="inputText"
    :isFocus="isFocus"
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
      <b-button-group
        @click="doPin"
        @mouseover="doShow"
        @mousemove="doShow"
        @mouseout="doHide"
      >
        <b-button class="input-group-text no-border-radius" :pressed="reveal" tabindex="-1" :variant="(pinned) ? 'primary' : 'light'">
          <icon name="eye"></icon>
        </b-button>
      </b-button-group>
    </template>
  </base-input-group>
</template>
<script>
import BaseInputGroup from './BaseInputGroup'

const components = {
  BaseInputGroup
}

import { computed, ref, unref } from '@vue/composition-api'
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

  const reveal = ref(false)
  const pinned = ref(false)
  const type = computed(() => unref(reveal) ? 'text' : 'password')
  const doPin = () => {
    pinned.value = !pinned.value
    expirePin()
  }
  let expirePinTimeout
  const expirePin = () => { // expires pinned `password` reveal
    if (expirePinTimeout)
      clearTimeout(expirePinTimeout)
    if (pinned.value) {
      reveal.value = true
      expirePinTimeout = setTimeout(() => { // hide again after 10s
        reveal.value = false
        pinned.value = false
      }, 10000)
    }
  }
  const doShow = () => {
    if (!pinned.value)
      reveal.value = true
  }
  const doHide = () => {
    if (!pinned.value)
      reveal.value = false
  }

  return {
    // useInput
    inputPlaceholder: placeholder,
    inputReadonly: readonly,
    inputTabIndex: tabIndex,
    inputText: text,
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

    inputType: type,
    reveal,
    pinned,
    doPin,
    doShow,
    doHide
  }
}

// @vue/component
export default {
  name: 'base-input-group-password',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
