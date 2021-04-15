<template>
  <base-form-group
    class="base-form-group-input-password-generator"
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
      :readonly="readonly"
      :tabIndex="inputTabIndex"
      :type="inputType"
      :value="inputValue"
      :autocomplete="namespace || 'password'"
      @input="onInput"
      @change="onChange"
      @focus="onFocus"
      @blur="onBlur"
    />
    <template v-slot:append>
      <b-button
        class="input-group-text" variant="light"
        :id="uuid"
        :aria-label="$t('Generate password')" :title="$t('Generate password')"
        ><icon name="random"></icon></b-button>
      <b-popover
        triggers="focus blur click"
        placement="bottom"
        :target="uuid"
        :title="$t('Generate password')"
        :show.sync="isShowGenerator"
        @shown="doShowGenerator"
        @hidden="doHideGenerator">
        <div ref="generator">
          <b-form-row>
            <b-col><b-form-input v-model="options.pwlength" type="range" min="6" max="32"></b-form-input></b-col>
            <b-col>{{ $t('{count} characters', { count: options.pwlength }) }}</b-col>
          </b-form-row>
          <b-form-row>
            <b-col><b-form-checkbox v-model="options.upper">ABC</b-form-checkbox></b-col>
            <b-col><b-form-checkbox v-model="options.lower">abc</b-form-checkbox></b-col>
          </b-form-row>
          <b-form-row>
            <b-col><b-form-checkbox v-model="options.digits">123</b-form-checkbox></b-col>
            <b-col><b-form-checkbox v-model="options.special">!@#</b-form-checkbox></b-col>
          </b-form-row>
          <b-form-row>
            <b-col><b-form-checkbox v-model="options.brackets">({&lt;</b-form-checkbox></b-col>
            <b-col><b-form-checkbox v-model="options.high">äæ±</b-form-checkbox></b-col>
          </b-form-row>
          <b-form-row>
            <b-col><b-form-checkbox v-model="options.ambiguous">0Oo</b-form-checkbox></b-col>
          </b-form-row>
          <b-form-row>
            <b-col class="text-right"><b-button variant="primary" size="sm" @click="doGenerate">{{ $t('Generate') }}</b-button></b-col>
          </b-form-row>
        </div>
      </b-popover>
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
  </base-form-group>
</template>
<script>
import BaseFormGroup from './BaseFormGroup'

const components = {
  BaseFormGroup
}

import { computed, ref, toRefs, unref } from '@vue/composition-api'
import { v4 as uuidv4 } from 'uuid'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import password from '@/utils/password'

export const props = {
  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,

  options: {
    type: Object,
    default: () => ({
      pwlength: 8,
      upper: true,
      lower: true,
      digits: true,
      special: false,
      brackets: false,
      high: false,
      ambiguous: false
    })
  }
}

export const setup = (props, context) => {

  const {
    options
  } = toRefs(props)

  const metaProps = useInputMeta(props, context)

  const uuid = uuidv4()

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

  const isShowGenerator = ref(false)
  const doShowGenerator = () => { isShowGenerator.value = true }
  const doHideGenerator = () => { isShowGenerator.value = false }

  const doGenerate = () => {
    onInput(password.generate(options.value))
  }

  return {
    uuid,

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
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,

    inputType: type,
    reveal,
    pinned,
    doPin,
    doShow,
    doHide,

    isShowGenerator,
    doShowGenerator,
    doHideGenerator,
    doGenerate
  }
}

// @vue/component
export default {
  name: 'base-form-group-input-password-generator',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
.base-input[type="password"] {
  font-family: $font-family-monospace;
}
</style>
