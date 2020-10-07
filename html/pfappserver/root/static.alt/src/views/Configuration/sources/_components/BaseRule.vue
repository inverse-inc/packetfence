<template>
  <div class="w-100">
    <b-link @click="onToggle"
      :class="{
        'text-danger': inputState === false,
        'text-primary': inputState !== false && actionKey,
        'text-secondary': inputState !== false && !actionKey
      }"
    >
      <icon v-if="!isCollapse" name="chevron-circle-down" class="mr-2 mb-1"/>
      <icon v-else name="chevron-circle-right" class="mr-2 mb-1"/>
      {{ ruleName }}
    </b-link>
    <b-collapse :visible="!isCollapse" tabIndex="-1" ref="rootRef" @show="onShow" @hidden="onHidden">
      <template v-if="isRendered">
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
      </template>
    </b-collapse>
  </div>
</template>
<script>
import { computed, unref } from '@vue/composition-api'
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

import useArrayCollapse from '@/composables/useArrayCollapse'
import useEventActionKey from '@/composables/useEventActionKey'
import { useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
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

  const metaProps = useInputMeta(props, context)

  const {
    value
  } = useInputValue(metaProps, context)

  const {
    state
  } = useInputValidator(metaProps, value)

  const ruleName = computed(() => {
    const { id, description } = unref(value) || {}
    let ruleName = id || 'unknown'
    if (description)
      ruleName += ` (${description})`
    return ruleName
  })

  const actionKey = useEventActionKey()

  const {
    isCollapse,
    isRendered,

    onToggle,
    onCollapse,
    onExpand,
    onShow,
    onHidden
  } = useArrayCollapse(actionKey, context)

  return {
    inputState: state,
    inputValue: value,

    ruleName,
    actionKey,
    isCollapse,
    isRendered,

    onToggle,
    onCollapse,
    onExpand,
    onShow,
    onHidden
  }
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
