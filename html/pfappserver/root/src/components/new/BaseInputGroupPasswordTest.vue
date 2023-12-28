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
      :data-namespace="namespace"
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
      <b-button-group>
        <b-button :disabled="!canTest" tabindex="-1" variant="light" class="py-0"
          @click="doTest"
        >
          <span v-show="!isTesting">{{ buttonLabel || $t('Test') }}</span>
          <icon v-show="isTesting" name="circle-notch" spin></icon>
        </b-button>
      </b-button-group>

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

import { computed, inject, ref, toRefs, unref, watch } from '@vue/composition-api'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import i18n from '@/utils/locale'

export const props = {
  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,

  buttonLabel: {
    type: String
  },
  test: {
    type: Function,
    default: () => new Promise((resolve, reject) => reject(new Error('Missing test function.')))
  },
  testLabel: {
    type: String
  }
}

export const setup = (props, context) => {

  const {
    test,
    testLabel
  } = toRefs(props)

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

  const isTesting = ref(false)
  const canTest = computed(() => !unref(isLocked) && !unref(isTesting) && unref(value))
  let testState = ref(null)
  let testInvalidFeedback = ref(undefined)
  let testValidFeedback = ref(undefined)

  const form = inject('form', ref({}))
  const doTest = () => {
    isTesting.value = true
    testState.value = false
    testInvalidFeedback.value = testLabel.value || i18n.t('Testing...')
    testValidFeedback.value = undefined

    Promise.resolve(unref(test)(value.value, form.value)).then(message => {
      testState.value = true
      testInvalidFeedback.value = undefined
      testValidFeedback.value = message || i18n.t('Test succeeded.')
    }).catch(message => {
      testState.value = false
      testInvalidFeedback.value = message || i18n.t('Test failed with unknown error.')
      testValidFeedback.value = undefined
    }).finally(() => {
      isTesting.value = false
    })
  }
  const wrappedState = computed(() => (testState.value !== null) ? unref(testState) : unref(state))
  const wrappedInvalidFeedback = computed(() => (testState.value !== null) ? unref(testInvalidFeedback) : unref(invalidFeedback))
  const wrappedValidFeedback = computed(() => (testState.value !== null) ? unref(testValidFeedback) : unref(validFeedback))
  const wrappedIsLocked = computed(() => unref(isLocked) || unref(isTesting))

  watch(value, () => { // when `value` is mutated
    testState.value = null // clear `state`
    expirePin()
  })

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
    isLocked: wrappedIsLocked,
    onFocus,
    onBlur,

    // useInputValue
    inputValue: value,
    onInput,
    onChange,

    // useInputValidator
    inputState: wrappedState,
    inputInvalidFeedback: wrappedInvalidFeedback,
    inputValidFeedback: wrappedValidFeedback,

    canTest,
    doTest,
    isTesting,

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
  name: 'base-input-group-password-test',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
