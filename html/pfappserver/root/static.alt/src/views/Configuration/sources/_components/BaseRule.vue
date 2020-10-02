<template>
  <div>
    <b-link @click="onToggle"
      class="text-primary"
    >
      <icon v-if="!isCollapse" name="chevron-circle-down"
        class="mr-2" :class="{ 'text-primary': actionKey, 'text-secondary': !actionKey }"/>
      <icon v-else name="chevron-circle-right"
        class="mr-2" :class="{ 'text-primary': actionKey, 'text-secondary': !actionKey }"/>
      {{ ruleName }}
    </b-link>
    <b-collapse :visible="!isCollapse" tabIndex="-1">
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
    </b-collapse>
  </div>
</template>
<script>
import { ref, computed, unref } from '@vue/composition-api'
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

import useEventActionKey from '@/composables/useEventActionKey'
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

  const metaProps = useInputMeta(props, context)

  const {
    value
  } = useInputValue(metaProps, context)

  const actionKey = useEventActionKey()
  const isCollapse = ref(true)
  const ruleName = computed(() => {
    const { id, description } = unref(value)
    let ruleName = id || 'unknown'
    if (description)
      ruleName += ` (${description})`
    return ruleName
  })

  const onToggle = () => {
    const toggleAll = unref(actionKey)
    if (toggleAll) {
      const { parent: { $children = [] } = {} } = context
      if (unref(isCollapse))
        $children.map(({ onExpand = () => {} }) => onExpand())
      else
        $children.map(({ onCollapse = () => {} }) => onCollapse())
    }
    else
      isCollapse.value = !isCollapse.value
  }
  const onCollapse = () => (isCollapse.value = true)
  const onExpand = () => (isCollapse.value = false)

  return {
    actionKey,
    isCollapse,
    ruleName,

    onToggle,
    onCollapse,
    onExpand
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
