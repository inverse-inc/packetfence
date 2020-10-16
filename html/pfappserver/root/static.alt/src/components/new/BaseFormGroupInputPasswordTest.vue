<template>
  <base-form-group
    class="base-form-group-input-password-test"
    :label-cols="labelCols"
    :column-label="columnLabel"
    :text="text"
    :disabled="isLocked"
    :state="inputState"
    :invalid-feedback="inputInvalidFeedback"
    :valid-feedback="inputValidFeedback"
    :is-focus="isFocus"
  >
    <b-form-input ref="input"
      class="base-input"
      :class="{
        'is-focus': isFocus,
        'is-blur': !isFocus
      }"
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
          <b-button :disabled="!canTest" tabindex="-1" variant="light"
            @click="doTest"
          >
            {{ testLabel || $t('Test') }}
            <icon v-show="isTesting" name="circle-notch" spin class="ml-2 mr-1"></icon>
          </b-button>

          <b-button-group
            @click="doPin"
            @mouseover="doShow"
            @mousemove="doShow"
            @mouseout="doHide"
          >
            <b-button class="input-group-text no-border-radius" :disabled="!canTest" :pressed="reveal" tabindex="-1" :variant="(pinned) ? 'primary' : 'light'">
              <icon name="eye"></icon>
            </b-button>
          </b-button-group>
        </b-button-group>
    </template>
  </base-form-group>
</template>
<script>
import BaseFormGroup from './BaseFormGroup'

const components = {
  BaseFormGroup
}

import { computed, ref, toRefs, unref, watch } from '@vue/composition-api'
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

  test: {
    type: Function,
    default: () => {
      return new Promise((resolve, reject) => {
        setTimeout(() => {
          if (Math.round(Math.random() * 100) % 2 === 0)
            resolve('success!')
          else
            reject('error!')
        }, 3000)
      })
    }
  },
  testLabel: {
    type: String
  },
}

export const setup = (props, context) => {

  const {
    test
  } = toRefs(props)

  const metaProps = useInputMeta(props, context)

  const {
    placeholder,
    tabIndex,
    text,
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
  const canTest = computed(() => !unref(isLocked) && !unref(isTesting) && unref(value) && unref(state) !== false)
  let testState = ref(null)
  let testInvalidFeedback = ref(undefined)
  let testValidFeedback = ref(undefined)

  const doTest = () => {
    isTesting.value = true
    testState.value = false
    testInvalidFeedback.value = i18n.t('Waiting for Test...')
    testValidFeedback.value = undefined
    Promise.resolve(unref(test)()).then(message => {
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
  const wrappedState = computed(() => {
    return (testState.value !== null) ? unref(testState) : unref(state)
  })
  const wrappedInvalidFeedback = computed(() => {
    return (testState.value !== null) ? unref(testInvalidFeedback) : unref(invalidFeedback)
  })
  const wrappedValidFeedback = computed(() => {
    return (testState.value !== null) ? unref(testValidFeedback) : unref(validFeedback)
  })

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
    inputTabIndex: tabIndex,
    inputText: text,
    isFocus,
    isLocked,
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
  name: 'base-form-group-input-password-test',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<!--
<style lang="scss">
.base-form-group-input-password-test {
  & > .form-row {
    & > .col {
      & > .input-group {

        transition: border-color .3s;
        border-top: 1px solid transparent;
        border-right: 0px;
        border-bottom: 1px solid transparent;
        border-left: 0px;

        &:first-child {
          border-top-left-radius: $border-radius !important;
          border-bottom-left-radius: $border-radius !important;
          border-left: 1px solid transparent;
        }
        &:last-child {
          border-top-right-radius: $border-radius !important;
          border-bottom-right-radius: $border-radius !important;
          border-right: 1px solid transparent;
        }
      }
      & > .is-focus {
          border-color: $input-focus-border-color !important;
      }
      & > .is-invalid {
        border-color: $form-feedback-invalid-color !important;
      }
      & > .is-valid {
        border-color: $form-feedback-valid-color !important;
      }
    }
  }
}
</style>
-->
