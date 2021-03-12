<template>
  <base-form-group
    class="base-form-group-password-options"
    :label-cols="labelCols"
    :column-label="columnLabel"
    :text="text"
    :disabled="isLocked"
    :state="inputState"
    :invalid-feedback="inputInvalidFeedback"
    :valid-feedback="inputValidFeedback"
  >
    <b-row class="w-100">
      <b-col cols="6">
        <base-input class="pt-3" type="range" :min="min" :max="max"
          v-model="inputValue.pwlength"
          :column-label="$t('Length')"
          :text="$t('{count} characters', { count: inputValue.pwlength })"
          :disabled="isLocked" :readonly="readonly"
        />
        <base-input-toggle v-model="inputValue.upper"
          :options="[
            { value: false, label: 'ABC' },
            { value: true, label: 'ABC', color: 'var(--primary)' }
          ]" 
          label-right
          :text="$t('Include uppercase characters')"
          :disabled="isLocked" :readonly="readonly"
        />
        <base-input-toggle v-model="inputValue.lower"
          :options="[
            { value: false, label: 'abc' },
            { value: true, label: 'abc', color: 'var(--primary)' }
          ]" 
          label-right
          :text="$t('Include lowercase characters')"
          :disabled="isLocked" :readonly="readonly"
        />
        <base-input-toggle v-model="inputValue.digits"
          :options="[
            { value: false, label: '123' },
            { value: true, label: '123', color: 'var(--primary)' }
          ]" 
          label-right
          :text="$t('Include digits')"
          :disabled="isLocked" :readonly="readonly"
        />
      </b-col>
      <b-col cols="6">
        <base-input-toggle v-model="inputValue.special"
          :options="[
            { value: false, label: '!@#' },
            { value: true, label: '!@#', color: 'var(--primary)' }
          ]" 
          label-right
          :text="$t('Include special characters')"
          :disabled="isLocked" :readonly="readonly"
        />
        <base-input-toggle v-model="inputValue.brackets"
          :options="[
            { value: false, label: '({&lt;' },
            { value: true, label: '({&lt;', color: 'var(--primary)' }
          ]" 
          label-right
          :text="$t('Include brackets/parenthesis')"
          :disabled="isLocked" :readonly="readonly"
        />
        <base-input-toggle v-model="inputValue.high"
          :options="[
            { value: false, label: 'äæ±' },
            { value: true, label: 'äæ±', color: 'var(--primary)' }
          ]" 
          label-right
          :text="$t('Include accentuated characters')"
          :disabled="isLocked" :readonly="readonly"
        />
        <base-input-toggle v-model="inputValue.ambiguous"
          :options="[
            { value: false, label: '0Oo' },
            { value: true, label: '0Oo', color: 'var(--primary)' }
          ]" 
          label-right
          :text="$t('Include ambiguous characters')"
          :disabled="isLocked" :readonly="readonly"
        />
      </b-col>
    </b-row>
  </base-form-group>
</template>
<script>
import {
  BaseFormGroup,
  BaseInput,
  BaseInputToggle
} from '@/components/new/'

const components = {
  BaseFormGroup,
  BaseInput,
  BaseInputToggle
}

//import { computed, ref } from '@vue/composition-api'
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
  
  // overload defaults
  min: {
    type: String,
    default: '8'
  },
  max: {
    type: String,
    default: '64'
  }
}

export const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    isLocked
  } = useInput(metaProps, context)

  const {
    value
  } = useInputValue(metaProps, context)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value)

  return {
    // useInput
    isLocked,

    // useInputValue
    inputValue: value,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback
  }
}

// @vue/component
export default {
  name: 'base-form-group-password-options',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
