<template>
  <div>
    <form-group-status :namespace="`${namespace}.status`"
      :column-label="$i18n.t('Status')"
      :label-cols="2" class="mb-0"
    />
    <form-group-identifier :namespace="`${namespace}.id`"
      :column-label="$i18n.t('Name')"
      :label-cols="2" class="mb-1"
    />
    <form-group-description :namespace="`${namespace}.description`"
      :column-label="$i18n.t('Description')"
      :label-cols="2" class="mb-1"
    />
    <form-group-match :namespace="`${namespace}.match`"
      :column-label="$i18n.t('Matches')"
      :label-cols="2" class="mb-1"
    />
    <form-group-conditions :namespace="`${namespace}.conditions`"
      :column-label="$i18n.t('Conditions')"
      :label-cols="2" class="mb-1"
    />
    <form-group-actions :namespace="`${namespace}.actions`"
      :column-label="$i18n.t('Actions')"
      :label-cols="2" class="mb-1"
    />
  </div>
</template>
<script>
import {
  BaseFormGroupInput,
  BaseFormGroupSelectOne,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import BaseRuleFormGroupActions from './BaseRuleFormGroupActions'
import BaseRuleFormGroupConditions from './BaseRuleFormGroupConditions'

const components = {
  FormGroupActions:     BaseRuleFormGroupActions,
  FormGroupConditions:  BaseRuleFormGroupConditions,
  FormGroupDescription: BaseFormGroupInput,
  FormGroupIdentifier:  BaseFormGroupInput,
  FormGroupMatch:       BaseFormGroupSelectOne,
  FormGroupStatus:      BaseFormGroupToggleDisabledEnabled,
}

import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useInputMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

const props = {
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,

  value: {
    type: Object
  }
}

const setup = (props, context) => {
/*
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

    // useInputValue
    inputValue: value,
    onInput,
    onChange,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback
  }
  */
}

// @vue/component
export default {
  name: 'base-rule',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
