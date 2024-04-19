<template>
  <base-form-group
    class="base-form-group-input-test"
    :column-label="columnLabel"
    :content-cols="contentCols"
    :content-cols-sm="contentColsSm"
    :content-cols-md="contentColsMd"
    :content-cols-lg="contentColsLg"
    :content-cols-xl="contentColsXl"
    :label-cols="labelCols"
    :label-cols-sm="labelColsSm"
    :label-cols-md="labelColsMd"
    :label-cols-lg="labelColsLg"
    :label-cols-xl="labelColsXl"
    :text="text"
    :disabled="isLocked"
    :state="inputState"
    :invalid-feedback="inputInvalidFeedback"
    :valid-feedback="inputValidFeedback"
    :api-feedback="apiFeedback"
    :is-focus="isFocus"
  >
    <b-form-input ref="input"
      class="base-input"
      :class="{
        'is-focus': isFocus,
        'is-blur': !isFocus
      }"
      :data-namespace="namespace"
      :disabled="isLocked"
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
    </template>
  </base-form-group>
</template>
<script>
import BaseFormGroup from './BaseFormGroup'

const components = {
  BaseFormGroup
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
    type: [Function, Boolean],
    default: () => new Promise((resolve, reject) => reject(new Error('Missing test function.')))
  },
  testLabel: {
    type: String
  },
}

export const setup = (props, context) => {

  const {
    test,
    testLabel
  } = toRefs(props)

  const metaProps = useInputMeta(props, context)

  const {
    placeholder,
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
    onChange,
    onInput
  } = useInputValue(metaProps, context)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value)

  const isTesting = ref(false)
  const canTest = computed(() => !unref(isLocked) && !unref(isTesting) && unref(value) && unref(state) !== false && test.value.constructor == Function)
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
  })

  return {
    // useInput
    inputPlaceholder: placeholder,
    inputTabIndex: tabIndex,
    inputText: text,
    inputType: type,
    isFocus,
    isLocked: wrappedIsLocked,
    onFocus,
    onBlur,

    // useInputValue
    inputValue: value,
    onChange,
    onInput,

    // useInputValidator
    inputState: wrappedState,
    inputInvalidFeedback: wrappedInvalidFeedback,
    inputValidFeedback: wrappedValidFeedback,

    canTest,
    doTest,
    isTesting
  }
}

// @vue/component
export default {
  name: 'base-form-group-input-test',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
