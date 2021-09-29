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
    <b-input-group ref="input-group"
      class="is-borders"
      :class="{
        'is-focus': isFocus || isShown,
        'is-blur': !(isFocus || isShown),
        'is-valid': inputState === true,
        'is-invalid': inputState === false
      }"
    >
      <b-form-input ref="input"
        class="base-form-group-input base-input"
        :disabled="isLocked"
        :readonly="inputReadonly"
        :state="inputState"
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
        <b-button v-if="isLocked"
          class="input-group-text"
          :disabled="true"
          tabIndex="-1"
        >
          <icon ref="icon-lock"
            name="lock"
          />
        </b-button>
        <b-form-datepicker v-else
          ref="datepickerRef"
          button-only right
          button-variant="light"
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
    validFeedback,
    apiFeedback
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
    inputApiFeedback: apiFeedback,

    datepickerRef,
    isShown,
    onShown,
    onHidden
  }
}

// @vue/component
export default {
  name: 'base-form-group-input-date',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.base-form-group-input-date {
  border-radius: $border-radius !important;
}
</style>
