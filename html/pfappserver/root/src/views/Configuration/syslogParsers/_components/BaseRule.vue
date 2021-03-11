<template>
  <div class="w-100 py-2">
    <b-link @click="doToggle"
      class="d-block"
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
        <form-group-identifier :namespace="`${namespace}.name`"
          :column-label="$i18n.t('Name')"
          :label-cols="2" class="mb-1"
        />
        <form-group-regex :namespace="`${namespace}.regex`"
          :column-label="$i18n.t('Regex')"
          :label-cols="2" class="mb-1"
        />
        <form-group-actions :namespace="`${namespace}.actions`"
          :column-label="$i18n.t('Actions')"
          :label-cols="2" class="mb-1"
        />
        <form-group-last-if-match :namespace="`${namespace}.last_if_match`"
          :column-label="$i18n.t('Last If Match')"
          :text="$i18n.t('Stop processing rules if this rule matches.')"
          :label-cols="2" class="mb-0"
        />
        <form-group-ip-mac-translation :namespace="`${namespace}.ip_mac_translation`"
          :column-label="$i18n.t('IP ⇄ MAC')"
          :text="$i18n.t('Perform automatic translation of IPs to MACs and the other way around.')"
          :label-cols="2" class="mb-0"
        />
      </template>
    </b-collapse>
  </div>
</template>
<script>
import { computed, unref } from '@vue/composition-api'
import {
  BaseFormGroupInput,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import BaseRuleFormGroupActions from './BaseRuleFormGroupActions'

const components = {
  FormGroupActions:           BaseRuleFormGroupActions,
  FormGroupRegex:             BaseFormGroupInput,
  FormGroupIdentifier:        BaseFormGroupInput,
  FormGroupLastIfMatch:       BaseFormGroupToggleDisabledEnabled,
  FormGroupIpMacTranslation:  BaseFormGroupToggleDisabledEnabled,
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
    const { id } = unref(value) || {}
    return id || 'unknown'
  })

  const actionKey = useEventActionKey()

  const {
    isCollapse,
    isRendered,

    doToggle,
    doCollapse,
    doExpand,
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

    doToggle,
    doCollapse,
    doExpand,
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
