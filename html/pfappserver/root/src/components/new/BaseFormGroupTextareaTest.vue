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
    <b-input-group
      class="is-borders"
      :class="{
        'is-focus': isFocus,
        'is-blur': !isFocus,
        'is-valid': inputState === true,
        'is-invalid': inputState === false
      }"
    >
      <b-form-textarea ref="input"
        class="base-form-input"
        :disabled="isLocked"
        :readonly="inputReadonly"
        :state="inputState"
        :placeholder="inputPlaceholder"
        :tabIndex="inputTabIndex"
        :type="inputType"
        :value="inputValue"
        :rows="rows"
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
        <template v-if="!isLocked">
          <slot name="append"></slot>
        </template>
        <b-button v-else
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
    <template v-if="!isLocked">
      <b-button :disabled="!canTest" tabindex="-1" variant="outline-primary" size="sm" class="my-1 col-6 col-sm-4 col-md-3 col-lg-2 col-xl-1"
        @click="doTest"
      >
        <span v-show="!isTesting">{{ buttonLabel || $t('Test') }}</span>
        <icon v-show="isTesting" name="circle-notch" spin></icon>
      </b-button>
    </template>
    <template v-slot:description v-if="inputText">
      <div v-html="inputText"/>
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

  maxRows: {
    type: [Number, String]
  },
  rows: {
    type: [Number, String],
    default: 3
  },
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
    validFeedback
  } = useInputValidator(metaProps, value)

  const isTesting = ref(false)
  const canTest = computed(() => !unref(isLocked) && !unref(isTesting) && unref(value) && unref(state) !== false)
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
    inputReadonly: readonly,
    inputTabIndex: tabIndex,
    inputText: text,
    inputType: type,
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
    isTesting
  }
}

// @vue/component
export default {
  name: 'base-form-group-textarea-test',
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
